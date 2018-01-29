--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 17:35
-- 查询db和shared缓存
--

local cjson = require "cjson"

local CONST = require "core.constants"
local CACHE_KEY = CONST.CACHE_KEY
local PHI_ROUTER_DICT = CONST.DICTS.PHI_ROUTER
local MATCH = CACHE_KEY.ROUTER .. "*"
local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE

local Lock = require "resty.lock"
local LOCK_NAME = CONST.DICTS.PHI_LOCK

local SHARED_DICT = ngx.shared[PHI_ROUTER_DICT]

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local class = {}
local _M = {}

-- 缓存版本
function _M.version()
    return SHARED_DICT:get("version")
end

-- 升级缓存版本
function _M.incrVersion()
    return SHARED_DICT:incr("version", 1, 0)
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
    local routerKey = CACHE_KEY.ROUTER .. hostkey

    local policiesStr = SHARED_DICT:get(routerKey)

    if policiesStr then
        LOGGER(DEBUG, "shared缓存命中！hostkey:", hostkey)
        local result = cjson.decode(policiesStr)
        if not result.skipRouter then
            table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
        end
        -- 异步更新worker缓存
        self:crudEvent(hostkey, EVENTS.CREATE, result)
        return result
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
        table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
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
        local result = cjson.decode(policiesStr)
        table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
        return result
    end

    -- step 7:释放锁
    local ok, err = lock:unlock()
    if not ok then
        LOGGER(ERR, "解除锁[" .. routerKey .. "]失败！err:", err)
    end
    local result = cjson.decode(policiesStr)
    table.sort(result.policies, function(r1, r2) return r1.order < r2.order end)
    return result
end

-- 新增or更新路由规则
function _M:setRouterPolicy(hostkey, policyStr)
    local str = policyStr
    if type(str) == "table" then
        str = cjson.encode(policyStr)
    end
    local routerKey = CACHE_KEY.ROUTER .. hostkey
    local ok, err = self.dao:setRouterPolicy(routerKey, str)
    if ok then
        ok, err = SHARED_DICT:set(routerKey, str)
        -- 这里使用hostkey
        self:crudEvent(hostkey, EVENTS.CREATE, policyStr)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]保存路由规则到shared_dict失败！err:", err)
        end
    end
    return ok, err
end

-- 删除路由规则
function _M:delRouterPolicy(hostkey)
    local routerKey = CACHE_KEY.ROUTER .. hostkey

    local ok, err = self.dao:delRouterPolicy(routerKey)
    if ok then
        ok, err = SHARED_DICT:delete(routerKey)
        self:crudEvent(hostkey, EVENTS.DELETE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]从shared_dict删除路由规则失败！err:", err)
        end
    end
    return ok, err
end

-- 分页查询
function _M:getAllRouterPolicy(cursor, count)
    local ok, err = self.dao:getAllRouterPolicy(cursor, MATCH, count)
    if err then
        LOGGER(ERR, "全量查询路由规则失败！err:", err)
    end
    return ok, err
end

function class:new(dao)
    return setmetatable({ dao = dao }, { __index = _M })
end

return class