--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/12
-- Time: 16:00
-- 简易的针对uri的全局降级开关
--
local response = require "core.response"
local ngx_redirect = ngx.redirect
local HTTP_MOVED_TEMPORARILY = ngx.HTTP_MOVED_TEMPORARILY
local cjson = require("cjson.safe")
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local function skip(self)
    LOGGER(ERR, "Cannot perform a demotion strategy ,degrader is nil")
    response.failure("Degradation strategy not found,Limited access,Service Temporarily Unavailable,please try again later :-)", 503)
end

local function redirect(self)
    LOGGER(DEBUG, "request will be degraded ,redirect to ", self.target)
    ngx_redirect(self.target, HTTP_MOVED_TEMPORARILY)
end

local function fake(self)
    LOGGER(DEBUG, "request will be degraded ,return fake data")
    response.fake(self.body, self.headers)
end

local SKIP_INSTANCE = {
    doDegrade = skip
}

local class = {}
-- 降级维度：按照请求的URI地址进行处理
-- 类型1、fake数据(接口级) 2、重定向(页面级)
function class:new(info)
    if info.skip then
        return SKIP_INSTANCE
    end

    if not info.target then
        return nil, "target must not be nil !"
    end
    local instance = new_tab(0, 5)
    local t = info.type
    if t == "fake" then
        local targetObj = cjson.decode(info.target)

        if targetObj then
            if targetObj.headers then
                instance.headers = targetObj.headers
                instance.body = cjson.encode(targetObj.body)
            else
                instance.headers = {}
                instance.headers["Content-Type"] = "application/json;charset=utf-8"
                instance.body = info.target
            end
        else
            instance.headers = {}
            instance.body = info.target
            instance.headers["Content-Type"] = "text/html;charset=utf-8"
        end
        instance.doDegrade = fake
    elseif t == "redirect" then
        instance.doDegrade = redirect
    else
        local err = "create degrader failed ,bad degrader type : " .. (t or "nil")
        LOGGER(ERR, err)
        return nil, err
    end

    instance.target = info.target
    instance.extend = info.extend
    instance.mapper = info.mapper
    if type(info.enabled) == "boolean" then
        instance.enabled = info.enabled
    else
        instance.enabled = info.enabled == "true"
    end
    return instance
end

return class