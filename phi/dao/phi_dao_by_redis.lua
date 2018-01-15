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
local cjson = require "cjson.safe"
local ALERT = ngx.ALERT

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
    local policiesStr, err = self.db:get(CONST.CACHE_KEY_PREFIX.ROUTER .. hostkey)
    if not err and policiesStr then
        return cjson.decode(policiesStr)
    end
    ngx.log(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的路由规则")
end

-- 此函数接收 主机名 的字符串，即此次请求需要访问的主机名称，返回规则列表
function _M:addRouterPolicy(hostkey, policy)
    local ok, err = self.db:set(CONST.CACHE_KEY_PREFIX.ROUTER .. hostkey, cjson.encode(policy))
    if not ok then
        ngx.log(ngx.ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则失败！err:", err)
    end
end

return class