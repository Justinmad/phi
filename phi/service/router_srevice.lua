--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 17:35
-- To change this template use File | Settings | File Templates.
--

-- 查询shared_dict
local ERR = ngx.ERR
local LOGGER = ngx.log
local CONST = require "core.constants"
local CACHE_KEY = CONST.CACHE_KEY
local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE
local Lock = require "resty.lock"
local LOCK_NAME = "phi"

local class = {}
local _M = {}
local SHARED_DICT = ngx.shared["phi_cache"]

function class:new(dao)
    _M.dao = dao
    return setmetatable({}, { __index = _M })
end

function _M:init_worker(observer)
    self.observer = observer
end

function _M:getRouterPolicy(hostkey)
    local routerKey = CACHE_KEY.CTRL_PREFIX .. hostkey .. CACHE_KEY.ROUTER

    local policiesStr = SHARED_DICT:get(routerKey)

    if policiesStr then
        return cjson.decode(policiesStr)
    end

    -- step 1:未查询到缓存
    local lock, err = Lock:new(LOCK_NAME)
    if not lock then
        LOGGER(ERR, "创建锁[" .. LOCK_NAME .. "]失败！err:", err)
        return nil, err
    end
    -- step 2:加锁
    local elapsed, err = lock:lock(routerKey)
    if not elapsed then
        LOGGER(ERR, "加锁[" .. routerKey .. "]失败！err:", err)
        return nil, err
    end
    -- step 3:获取锁，查询一次缓存，确保未被更新
    policiesStr = SHARED_DICT:get(routerKey)
    if policiesStr then
        local ok, err = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
        end
        local result = cjson.decode(policiesStr)
        -- 异步更新worker缓存
        self:crudEvent(routerKey, EVENTS.CREATE, result)
        return result
    end
    -- step 4:查询db
    policiesStr, err = self.dao:getRouterPolicy(routerKey)
    if err then
        LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]查询db失败！err:", err)
        local ok, msg = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", msg)
        end
        return nil, err
    end
    -- step 5:未查询到
    if not policiesStr then
        local ok, err = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
        end
        local result = { skipRouter = true }
        -- 保存一个兜底数据，避免频繁访问db
        SHARED_DICT:set(routerKey, cjson.encode(result))
        -- 异步更新worker缓存
        self:crudEvent(routerKey, EVENTS.CREATE, result)
        return result
    end

    -- step 6:更新缓存
    local ok, msg = SHARED_DICT:set(routerKey, policiesStr)
    if not ok then
        local ok, err = lock:unlock()
        if not ok then
            LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
        end
        LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]保存路由规则到shared_dict失败！err:", msg)
        return cjson.decode(policiesStr)
    end

    -- step 7:释放锁
    local ok, err = lock:unlock()
    if not ok then
        LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
    end
    -- 异步更新worker缓存
    local result = cjson.decode(policiesStr)
    self:crudEvent(routerKey, EVENTS.CREATE, policiesStr)
    return result
end

function _M:crudEvent(hostkey, event, data)
    self.observer.post(EVENTS.SOURCE, event, { hostkey = hostkey, data = data })
end

function _M.version()
    return SHARED_DICT:get("version")
end

function _M.incrVersion()
    return SHARED_DICT:incr("version", 1, 0)
end

function _M:setRouterPolicy(hostkey, policyStr)
    local routerKey = CACHE_KEY.CTRL_PREFIX .. hostkey .. CACHE_KEY.ROUTER
    local ok, err = self.dao:setRouterPolicy(routerKey, policyStr)
    if ok then
        ok, err = SHARED_DICT:set(routerKey, policyStr)
        self:incrVersion()
        self:crudEvent(routerKey, EVENTS.CREATE, policyStr)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]保存路由规则到shared_dict失败！err:", err)
        end
    end
    return ok, err
end

function _M:delRouterPolicy(hostkey)
    local routerKey = CACHE_KEY.CTRL_PREFIX .. hostkey .. CACHE_KEY.ROUTER

    local ok, err = self.dao:delRouterPolicy(routerKey)
    if ok then
        ok, err = SHARED_DICT:delete(routerKey)
        self:incrVersion()
        self:crudEvent(routerKey, EVENTS.DELETE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]从shared_dict删除路由规则失败！err:", err)
        end
    end
    return ok, err
end

return class