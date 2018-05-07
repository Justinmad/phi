--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/12
-- Time: 16:09
-- To change this template use File | Settings | File Templates.
--

local CONST = require "core.constants"
local mlcache = require "resty.mlcache"
local degrader_wrapper = require "component.limit_traffic.degrader_wrapper"
local pretty_write = require("pl.pretty").write
local worker_pid = ngx.worker.pid
local ipairs = ipairs

local EVENTS = CONST.EVENT_DEFINITION.SERVICE_DEGRADATION_EVENTS
local UPDATE = EVENTS.UPDATE

local SHARED_DICT_NAME = CONST.DICTS.PHI_DEGRADER
local PHI_EVENTS_DICT_NAME = CONST.DICTS.PHI_EVENTS

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log
local NIL_VALUE = { skip = true }

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local _M = {}

local function createDegrader(row)
    return degrader_wrapper:new(row)
end

-- 初始化worker
function _M:init_worker(observer)
    self.observer = observer
    -- 注册关注事件handler到指定事件源
    observer.register(function(data, event, source, pid)
        if worker_pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            -- 更新缓存
            self.cache:update()
            self:getDegrader(data.hostkey, data.uri)
            LOGGER(DEBUG, "received event; source=", source,
                    ", event=", event,
                    ", data=", pretty_write(data),
                    ", from process ", pid)
        end
    end, EVENTS.SOURCE, UPDATE)
    -- 集群处理
    observer.register(function(clusterData, event, source, pid)
        local data = clusterData.data
        self.cache:delete(data.hostkey .. ":" .. data.uri)
        self:getDegrader(data.hostkey, data.uri)
        self.observer.post(EVENTS.SOURCE, UPDATE, {
            hostkey = data.hostkey,
            uri = data.uri
        }, clusterData.unique, true) -- local event
        LOGGER(DEBUG, "received cluster event; source=", source,
                ", event=", event,
                ", data=", pretty_write(data),
                ", from process ", pid)
    end, EVENTS.SOURCE, "cluster")
end

function _M:updateEvent(hostkey, uri)
    self.observer.post(EVENTS.SOURCE, UPDATE, {
        hostkey = hostkey,
        uri = uri
    })
end

local function getFromDb(self, hostkey, uri)
    local res, err = self.dao:getDegradation(hostkey, uri)
    if err then
        -- 查询出现错误，10秒内不再查询
        LOGGER(ERR, "could not retrieve degrader:", err)
        return NIL_VALUE, nil, 10
    end
    return res or NIL_VALUE
end

function _M:getDegrader(hostkey, uri)
    return self.cache:get(hostkey .. ":" .. uri, nil, getFromDb, self, hostkey, uri)
end

function _M:getDegradations(hostkey)
    local res, err = self.dao:getDegradations(hostkey)
    if err then
        LOGGER(ERR, "could not retrieve degrader:", err)
    end
    return res, err
end

function _M:getDegradation(hostkey, uri)
    local res, err = self.dao:getDegradation(hostkey, uri)
    if err then
        LOGGER(ERR, "could not retrieve degrader:", err)
    end
    return res, err
end

function _M:addDegradations(hostkey, degradations)
    local ok, err = self.dao:addDegradations(hostkey, degradations)
    if ok then
        for _, d in ipairs(degradations) do
            ok, err = self.cache:set(hostkey .. ":" .. d.uri, nil, d.info)
            if not ok then
                LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存降级规则到mlcache失败！err:", err)
                self.dao:delDegradation(hostkey, d.uri)
            else
                self:updateEvent(hostkey, d.uri)
            end
        end
    end
    return ok, err
end

function _M:enabled(hostkey, uri, enabled)
    local ok
    local data, err = self.dao:enabled(hostkey, uri, enabled)
    if data then
        ok, err = self.cache:set(hostkey .. ":" .. uri, nil, data)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存降级规则到mlcache失败！err:", err)
            self.dao:enabled(hostkey, uri, not enabled)
        else
            self:updateEvent(hostkey, uri)
        end
    end
    return ok, err
end

function _M:delDegradation(hostkey, uri)
    local ok, err = self.dao:delDegradation(hostkey, uri)
    if ok then
        ok, err = self.cache:set(hostkey .. ":" .. uri, nil, NIL_VALUE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]从mlcache删除降级规则失败！err:", err)
        else
            self:updateEvent(hostkey, uri)
        end
    end
    return ok, err
end

-- 分页查询
function _M:getAllDegradations(from, count)
    local ok, err = self.dao:getAllDegradations(from, count)
    if err then
        LOGGER(ERR, "全量查询降级规则失败！err:", err)
    end
    return ok, err
end

local class = {}

function class:new(ref, config)
    -- new函数我会在init阶段调用，我在这里就初始化cache，并且在init函数中load部分数据，worker进程会fork这部分内存，相当于缓存的预热
    local cache, err = mlcache.new("degrader_cache", SHARED_DICT_NAME, {
        lru_size = config.degrader_lrucache_size or 1000, -- L1缓存大小，默认取1000
        ttl = 0, -- 缓存失效时间
        neg_ttl = 0, -- 未命中缓存失效时间
        resty_lock_opts = {
            -- 回源DB的锁配置
            exptime = 10, -- 锁失效时间
            timeout = 5 -- 获取锁超时时间
        },
        ipc_shm = PHI_EVENTS_DICT_NAME, -- 通知其他worker的事件总线
        l1_serializer = createDegrader -- 结果排序处理
    })
    if err then
        error("could not create mlcache for degrader cache ! err :" .. err)
    end
    return setmetatable({ dao = ref, cache = cache }, { __index = _M })
end

return class