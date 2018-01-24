--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 17:35
-- To change this template use File | Settings | File Templates.
--

-- 查询shared_dict
local ERR = ngx.ERR
local ALERT = ngx.ALERT
local LOGGER = ngx.log
local CONST = require "core.constants"
local CACHE_KEY = CONST.CACHE_KEY
local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE

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

    local policiesStr, err = SHARED_DICT:get(routerKey)

    if err or not policiesStr then
        policiesStr, err = self.dao:getRouterPolicy(routerKey)
        if err or not policiesStr then
            LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的路由规则")
        end
    end
    return policiesStr, err
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
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到db失败！err:", err)
    else
        ok, err = SHARED_DICT:set(routerKey, policyStr)
        self:incrVersion()
        self:crudEvent(hostkey, EVENTS.CREATE, policyStr)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到shared_dict失败！err:", err)
        end
    end
    return ok, err
end

function _M:delRouterPolicy(hostkey)
    local routerKey = CACHE_KEY.CTRL_PREFIX .. hostkey .. CACHE_KEY.ROUTER

    local ok, err = self.dao:delRouterPolicy(routerKey)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到db失败！err:", err)
    else
        ok, err = SHARED_DICT:delete(routerKey)
        self:incrVersion()
        self:crudEvent(hostkey, EVENTS.DELETE)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到shared_dict失败！err:", err)
        end
    end
    return ok, err
end

return class