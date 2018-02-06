--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/30
-- Time: 15:13
-- 对db和shared缓存中的upstream列表的CRUD
--
local cjson = require "cjson.safe"
local Lock = require "resty.lock"
local ngx_upstream = require "ngx.upstream"
local CONST = require "core.constants"

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log

local EVENTS = CONST.EVENT_DEFINITION.UPSTREAM_EVENTS
local PHI_UPSTREAM_DICT = CONST.DICTS.PHI_UPSTREAM

local SHARED_DICT = ngx.shared[PHI_UPSTREAM_DICT]
local LOCK_NAME = CONST.DICTS.PHI_LOCK

local _M = {}
function _M:init()
end

-- 初始化worker，主要是在事件总线中注册事件监听
function _M:init_worker(ev)
    self.observer = ev
    -- 关注配置中的peer的启停
    ev.register(function(data, event, source, pid)
        if ngx.worker.pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            if data[4] == nil then
                ngx_upstream.set_peer_down(data[1], data[2], data[3], data[4])
                LOGGER(NOTICE, "received event; source=", source,
                    ", event=", event,
                    ", data=", tostring(data),
                    ", from process ", pid)
            end
        end
    end, EVENTS.SOURCE)
end

-- 获取所有运行时信息,这个方法最多会获取1024条信息
function _M:getAllRuntimeInfo()
    local result = {}
    local upsNames = SHARED_DICT:get_keys()
    for _, name in ipairs(upsNames) do
        local info = self:getUpstreamServers(name)
        result[name] = info
    end
    return result
end

-- 需要通知其他worker进程peer状态改变
function _M:peerStateChangeEvent(upstreamName, isBackup, peerId, down)
    local event = down and EVENTS.PEER_DOWN or EVENTS.PEER_UP
    self.observer.post(EVENTS.SOURCE, event, { upstreamName, isBackup, peerId, down })
end

-- 需要通知其他worker进程更新缓存中的server信息
function _M:dynamicPeerStateChangeEvent(upstreamName, peerId, down)
    local event = down and EVENTS.DYNAMIC_PEER_DOWN or EVENTS.DYNAMIC_PEER_UP
    self.observer.post(EVENTS.DYNAMIC_PEER_SOURCE, event, { upstreamName, peerId, down })
end

-- 需要通知其他worker进程更新缓存中的upstream信息
function _M:dynamicUpsChangeEvent(upstreamName, ups)
    local event = ups and EVENTS.DEL or EVENTS.UPS_UPDATE
    self.observer.post(EVENTS.UPS_SOURCE, event, { upstreamName, ups })
end

-- 需要通知其他worker进程更新缓存中的upstream信息中的server
function _M:dynamicUpsServerChangeEvent(event, upstreamName, servers)
    self.observer.post(EVENTS.SERVER_SOURCE, event, { upstreamName, servers })
end

-- 动态添加upstream中的server
function _M:addUpstreamServers(upstream, servers)
    local ok, err
    -- 查询缓存
    local upstream = SHARED_DICT:get(upstream)
    -- 不存在或者动态upstream
    if (not upstream) or upstream.dynamic then
        ok, err = self.dao:addUpstreamServer(upstream, servers)
        if ok then
            -- 存入共享缓存
            local serversStr = cjson.encode(servers)
            ok, err = SHARED_DICT:set(upstream, serversStr)
            -- 发布服务列表更新事件
            self:dynamicUpsServerChangeEvent(EVENTS.SERVER_UPDATE, upstream, servers)
            if not ok then
                LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存server信息到shared_dict失败！err:", err)
            end
        end
    else
        err = "暂不支持对配置文件中的upstream进行编辑！"
    end
    return ok, err
end

-- 查询upstream中的所有server信息，包括shared缓存和配置文件中的所有数据
function _M:getUpstreamServers(upstream)
    local data
    local err
    local upstreamInfo = SHARED_DICT:get(upstream)
    if upstreamInfo then
        if upstreamInfo == "stable" then
            data = {}
            data["primary"] = ngx_upstream.get_primary_peers(upstream)
            data["backup"] = ngx_upstream.get_backup_peers(upstream)
        else
            data = upstreamInfo
        end
    else
        err = "不存在的upstream！"
    end

    return data, err
end

-- 获取upstream信息
function _M:getUpstream(upstream)
    local upstreamInfoStr = SHARED_DICT:get(upstream)
    if upstreamInfoStr then
        LOGGER(DEBUG, "shared缓存命中！upstream:", upstream)
        return type(upstreamInfoStr) == "table" and cjson.decode(upstreamInfoStr) or upstreamInfoStr
    end

    -- step 1:未查询到缓存
    local lock, newLockErr = Lock:new(LOCK_NAME)
    if not lock then
        LOGGER(ERR, "创建锁[" .. LOCK_NAME .. "]失败！err:", newLockErr)
        return nil, newLockErr
    end
    -- step 2:加锁
    local elapsed, lockErr = lock:lock("Upstream:" .. upstream)
    if not elapsed then
        LOGGER(ERR, "Upstream加锁[" .. upstream .. "]失败！err:", lockErr)
        return nil, lockErr
    end
    -- step 3:获取锁，查询一次缓存，确保未被更新
    upstreamInfoStr = SHARED_DICT:get(upstream)
    if upstreamInfoStr then
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. upstream .. "]失败！err:", unLockErr)
        end
        return cjson.decode(upstreamInfoStr)
    end
    -- step 4:查询db
    local dbErr
    upstreamInfoStr, dbErr = self.dao:getUpstreamServers(upstream)
    print(require("pl.pretty").write(upstreamInfoStr))
    if dbErr then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]查询db失败！err:", dbErr)
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. upstream .. "]失败！err:", unLockErr)
        end
        return nil, dbErr
    end
    -- step 5:未查询到
    if not upstreamInfoStr then
        -- 保存一个兜底数据，避免频繁访问db
        SHARED_DICT:set(upstream, "stable") -- 忽略结果
        local ok, err = lock:unlock()
        if not ok then
            LOGGER(ERR, "Upstream解除锁[" .. upstream .. "]失败！err:", err)
        end
        -- 异步更新worker缓存
        self:dynamicUpsChangeEvent(upstream, "stable")
        return "stable"
    end

    -- step 6:更新缓存
    local ok, msg = SHARED_DICT:set(upstream, upstreamInfoStr)
    -- 保存缓存失败
    if not ok then
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. upstream .. "]失败！err:", unLockErr)
        end
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存路由规则到shared_dict失败！err:", msg)
        -- worker缓存异步更新的情况下，在这里即使我们通知worker更新缓存，但是在高并发情况中依然会有请求会进入此方法来查询共享缓存
        -- 这样的话相反会造成worker缓存的重复更新，所以在这里不通知worker
        -- 原则上通知worker的前提必须是在shared缓存中保存成功
        return cjson.decode(upstreamInfoStr)
    end

    -- step 7:释放锁
    local ok, err = lock:unlock()
    if not ok then
        LOGGER(ERR, "解除锁[" .. upstream .. "]失败！err:", err)
    end
    local result = cjson.decode(upstreamInfoStr)
    -- 异步更新worker缓存
    self:dynamicUpsChangeEvent(upstream, upstreamInfoStr)
    return result
end

-- 关闭指定的peer
function _M:setPeerDown(upstreamName, peerId, down, isBackup)
    local upstreamInfo = SHARED_DICT:get(upstreamName)
    local ok, err
    if upstreamInfo then
        if upstreamInfo == "stable" then
            ok, err = ngx_upstream.set_peer_down(upstreamName, isBackup, peerId, down)
            if ok then
                self:peerStateChangeEvent(upstreamName, isBackup, peerId, down)
            end
        else
            ok, err = self.dao:downUpstreamServer(upstreamName, peerId, down)
            if ok then
                self:dynamicPeerStateChangeEvent(upstreamName, peerId, down)
            end
        end
    else
        err = "不存在的upstream！"
    end
    return ok, err
end

local class = {}
function class:new(dao)
    return setmetatable({ dao = dao }, { __index = _M })
end

return class