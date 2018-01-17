--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 11:05
-- 主要负责从redis中加载数据
-- 必须要实现以下几个方法
-- selectRouterPolicy(hostkey)
--
local CONST = require "core.constants"
local cjson = require "cjson"
local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log

local class = {}

local _M = {}

function class:new(redis)
    if redis then
        return setmetatable({ db = redis }, { __index = _M }), nil
    end
    return nil, "redis实例不能为nil"
end

-- 根据主机名查询路由规则表
function _M:selectRouterPolicy(hostkey)
    local routerKey = CONST.CACHE_KEY.CTRL_PREFIX .. hostkey .. CONST.CACHE_KEY.ROUTER
    local policiesStr, err = self.db:get(routerKey)
    if not err and policiesStr then
        return cjson.decode(policiesStr)
    end
    if not err then
        err = "通过hostkey：[" .. hostkey .. "]未查询到对应的路由规则"
    end
    LOGGER(ALERT, err)
    return nil, err
end

-- 添加指定路由规则到db
function _M:addRouterPolicy(hostkey, policy)
    local ok, err = self.db:set(CONST.CACHE_KEY.CTRL_PREFIX .. hostkey .. CONST.CACHE_KEY.ROUTER, cjson.encode(policy))
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则失败！err:", err)
    end
end

return class