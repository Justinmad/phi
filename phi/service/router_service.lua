--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 17:35
-- 查询db和shared缓存
--
local cjson = require "cjson"
local CONST = require "core.constants"
local Lock = require "resty.lock"

local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE

local LOCK_NAME = CONST.DICTS.PHI_LOCK
local SHARED_DICT = ngx.shared[CONST.DICTS.PHI_ROUTER]

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local class = {}
local _M = {}

-- 缓存版本
function _M.version()
    return SHARED_DICT:get("__version")
end

-- 升级缓存版本
function _M.incrVersion()
    return SHARED_DICT:incr("__version", 1, 0)
end

-- 初始化worker
function _M:init_worker(observer)
    self.observer = observer
end

-- 发布路由规则CRUD事件
function _M:crudEvent(hostkey, event, data)
    self.observer.post(EVENTS.SOURCE, event, { hostkey = hostkey, data = data })
end

-- 获取单个路由规则
function _M:getRouterPolicy(hostkey)
    local policiesStr = SHARED_DICT:get(hostkey)
    if policiesStr then
        LOGGER(DEBUG, "shared缓存命中！hostkey:", hostkey)
        local result = cjson.decode(policiesStr)
        -- 共享缓存中的数据未经排序
        if not result.skipRouter then
            table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
        end
        return result
    end

    -- step 1:未查询到缓存
    local lock, newLockErr = Lock:new(LOCK_NAME)
    if not lock then
        LOGGER(ERR, "创建锁[" .. LOCK_NAME .. "]失败！err:", newLockErr)
        return nil, newLockErr
    end
    -- step 2:加锁
    local elapsed, lockErr = lock:lock("Router:" .. hostkey)
    if not elapsed then
        LOGGER(ERR, "加锁[" .. hostkey .. "]失败！err:", lockErr)
        return nil, lockErr
    end
    -- step 3:获取锁，查询一次缓存，确保未被更新
    policiesStr = SHARED_DICT:get(hostkey)
    if policiesStr then
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. hostkey .. "]失败！err:", unLockErr)
        end
        local result = cjson.decode(policiesStr)
        table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
        return result
    end
    -- step 4:查询db
    local dbErr
    policiesStr, dbErr = self.dao:getRouterPolicy(hostkey)
    if dbErr then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]查询db失败！err:", dbErr)
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. hostkey .. "]失败！err:", unLockErr)
        end
        return nil, dbErr
    end
    -- step 5:未查询到
    if not policiesStr then
        local result = { skipRouter = true }
        -- 保存一个兜底数据，避免频繁访问db
        SHARED_DICT:set(hostkey, cjson.encode(result)) -- 忽略结果
        local ok, err = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. hostkey .. "]失败！err:", err)
        end
        -- 异步更新worker缓存
        self:crudEvent(hostkey, EVENTS.CREATE, result)
        return result
    end

    -- step 6:更新缓存
    local ok, msg = SHARED_DICT:set(hostkey, policiesStr)
    -- 保存缓存失败
    if not ok then
        local ok, unLockErr = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. hostkey .. "]失败！err:", unLockErr)
        end
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到shared_dict失败！err:", msg)
        local result = cjson.decode(policiesStr)
        table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
        -- worker缓存异步更新的情况下，在这里即使我们通知worker更新缓存，但是在高并发情况中依然会有请求会进入此方法来查询共享缓存
        -- 这样的话相反会造成worker缓存的重复更新，所以在这里不通知worker
        -- 原则上通知worker的前提必须是在shared缓存中保存成功
        return result
    end

    -- step 7:释放锁
    local ok, err = lock:unlock()
    if not ok then
        LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
    end
    local result = cjson.decode(policiesStr)
    table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
    -- 异步更新worker缓存
    self:crudEvent(hostkey, EVENTS.CREATE, result)
    return result
end

-- 新增or更新路由规则
function _M:setRouterPolicy(hostkey, policyStr)
    local str = policyStr
    if type(str) == "table" then
        str = cjson.encode(policyStr)
    end
    local ok, err = self.dao:setRouterPolicy(hostkey, str)
    if ok then
        ok, err = SHARED_DICT:set(hostkey, str)
        -- 这里使用hostkey
        self:crudEvent(hostkey, EVENTS.CREATE, policyStr)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到shared_dict失败！err:", err)
        end
    end
    return ok, err
end

-- 删除路由规则
function _M:delRouterPolicy(hostkey)
    local ok, err = self.dao:delRouterPolicy(hostkey)
    if ok then
        ok, err = SHARED_DICT:delete(hostkey)
        self:crudEvent(hostkey, EVENTS.DELETE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]从shared_dict删除路由规则失败！err:", err)
        end
    end
    return ok, err
end

-- 分页查询
function _M:getAllRouterPolicy(from, count)
    local ok, err = self.dao:getAllRouterPolicy(from, count)
    if err then
        LOGGER(ERR, "全量查询路由规则失败！err:", err)
    end
    return ok, err
end

function class:new(dao)
    return setmetatable({ dao = dao }, { __index = _M })
end

return class