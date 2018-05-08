--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 15:46
-- 多级缓存的限流规则查询服务
-- @see
--[[
    限流规则类型:
    req     限制请求速率
    @see https://github.com/openresty/lua-resty-limit-traffic/blob/master/lib/resty/limit/req.md
        {
            "type"      : "req"         // 限流策略类型
            "rate"      : 200,          // 正常速率 200 req/sec
            "burst"     : 100,          // 突发速率 100 req/sec
            "mapper"    : "host",       // 限流flag
            "tag"       : "xxx",        // mapper函数的可选参数
            "rejected"  : "xxx",        // 拒绝策略
        }
    conn    限制并发连接数
    @see https://github.com/openresty/lua-resty-limit-traffic/blob/master/lib/resty/limit/conn.md
        {
            "type"      : "conn"        // 限流策略类型
            "conn"      : 200,          // 正常速率 200 并发连接
            "burst"     : 100,          // 突发速率 100 并发连接
            "mapper"    : "host",       // 限流flag
            "tag"       : "xxx",        // mapper函数的可选参数
            "rejected"  : "xxx",        // 拒绝策略
            "delay"     : 0.5           // 延迟时长
        }
    count   限制指定时间内的调用总次数
    @see https://github.com/openresty/lua-resty-limit-traffic/blob/master/lib/resty/limit/count.md
        {
            "type"          : "count"   // 限流策略类型
            "rate"          : 200,      // 每360秒允许200次调用
            "time_window"   : 200,      // 每360秒允许200次调用
            "mapper"        : "host",   // 限流flag
            "tag"           : "xxx",    // mapper函数的可选参数
            "rejected"      : "xxx"     // 拒绝策略
        }
    traffic 组合限流，前几种的组合
    @see https://github.com/openresty/lua-resty-limit-traffic/blob/master/lib/resty/limit/traffic.md
]] --
local mlcache = require "resty.mlcache"
local limiter_wrapper = require "component.limit_traffic.limiter_wrapper"
local CONST = require("core.constants")
local pretty_write = require("pl.pretty").write
local worker_pid = ngx.worker.pid
local sort = table.sort
local getn = table.getn

local PHI_EVENTS_DICT_NAME = CONST.DICTS.PHI_EVENTS
local SHARED_DICT_NAME = CONST.DICTS.PHI_LIMITER

local EVENTS = CONST.EVENT_DEFINITION.RATE_LIMITING_EVENTS
local UPDATE = EVENTS.UPDATE
local REBUILD = EVENTS.REBUILD
local NIL_VALUE = { skip = true }

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log

local function newLimiterWrapper(policy)
    return limiter_wrapper:new(policy)
end

local function updateLimiterWrapper(policy)
    return policy.wrapper:update(policy)
end

local _M = {}

function _M:init_worker(observer)
    self.observer = observer

    -- 注册关注事件handler到指定事件源
    observer.register(function(data, event, source, pid)
        if worker_pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            -- 更新缓存
            if event == REBUILD then
                self.cache:update()
                self:getLimiter(data)
            else
                self:getLimiter(data.hostkey):update(data.policy)
            end
            LOGGER(DEBUG, "received event; source=", source,
                    ", event=", event,
                    ", data=", pretty_write(data),
                    ", from process ", pid)
        end
    end, EVENTS.SOURCE, REBUILD, UPDATE)
    -- 集群处理
    observer.register(function(clusterData, event, source, pid)
        local data = clusterData.data
        self.cache:delete(data)
        self:getLimiter(data)
        self.observer.post(EVENTS.SOURCE, REBUILD, data, clusterData.unique, true) -- local event
        LOGGER(DEBUG, "received cluster event; source=", source,
                ", event=", event,
                ", data=", pretty_write(data),
                ", from process ", pid)
    end, EVENTS.SOURCE, "cluster")
end

function _M:updateEvent(updated, data)
    self.observer.post(EVENTS.SOURCE, updated and UPDATE or REBUILD, data)
end

local function getFromDb(self, hostkey)
    local res, err = self.dao:getLimitPolicy(hostkey)
    if err then
        -- 查询出现错误，10秒内不再查询
        LOGGER(ERR, "could not retrieve limiter:", err)
        return NIL_VALUE, nil, 10
    end
    return res or NIL_VALUE
end

function _M:getLimiter(hostkey)
    local result, err = self.cache:get(hostkey, nil, getFromDb, self, hostkey)
    return result, err
end

function _M:getLimitPolicy(hostkey)
    local res, err = self.dao:getLimitPolicy(hostkey)
    if err then
        LOGGER(ERR, "could not retrieve limiter:", err)
    end
    return res, err
end

-- 这不是一个并发安全的操作
function _M:setLimitPolicy(hostkey, policy)
    local oldVal, err = self.dao:setLimitPolicy(hostkey, policy)
    local ok
    if not err then
        -- 判断是否是更新操作，对于组合规则，更新LImiter的操作很复杂，直接重建更方便 :-) 但是重建会带来新的问题 TODO
        local inCache = self.cache:peek(hostkey) ~= nil
        local updated = inCache and oldVal and oldVal.type == policy.type and oldVal.mapper == policy.mapper and oldVal.tag == policy.tag and policy.policies and getn(policy.policies) < 1
        local opts
        if updated then
            policy.wrapper = self:getLimiter(hostkey)
            opts = { l1_serializer = updateLimiterWrapper }
        end
        ok, err = self.cache:set(hostkey, opts, policy)
        if ok then
            self:updateEvent(updated, updated and { hostkey = hostkey, policy = policy } or hostkey)
        else
            -- 保证数据一致性，旧值放回db
            self.dao:setLimitPolicy(hostkey, oldVal)
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存限流规则失败！err:", err)
        end
    end
    return ok, err
end

-- 删除限流规则
function _M:delLimitPolicy(hostkey)
    local ok, err = self.dao:delLimitPolicy(hostkey)
    if ok then
        ok, err = self.cache:set(hostkey, nil, NIL_VALUE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]从mlcache删除限流规则失败！err:", err)
        else
            self:updateEvent(false, hostkey)
        end
    end
    return ok, err
end

-- 分页查询
function _M:getAllLimitPolicy(from, count)
    local ok, err = self.dao:getAllLimitPolicy(from, count)
    if err then
        LOGGER(ERR, "全量查询限流规则失败！err:", err)
    end
    return ok, err
end

local class = {}

function class:new(dao, config)
    -- new函数我会在init阶段调用，我在这里就初始化cache，并且在init函数中load部分数据，worker进程会fork这部分内存，相当于缓存的预热
    local cache, err = mlcache.new("rate_limiting_cache", SHARED_DICT_NAME, {
        lru_size = config.limiter_lrucache_size or 1000, -- L1缓存大小，默认取1000
        ttl = 0, -- 缓存失效时间
        neg_ttl = 0, -- 未命中缓存失效时间
        resty_lock_opts = {
            -- 回源DB的锁配置
            exptime = 10, -- 锁失效时间
            timeout = 5 -- 获取锁超时时间
        },
        ipc_shm = PHI_EVENTS_DICT_NAME, -- 通知其他worker的事件总线
        l1_serializer = newLimiterWrapper -- 结果排序处理
    })
    if err then
        error("could not create mlcache for router cache ! err :" .. err)
    end
    return setmetatable({ dao = dao, cache = cache }, { __index = _M })
end

return class


