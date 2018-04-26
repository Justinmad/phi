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

local function redirect(self)
    ngx_redirect(self.target, HTTP_MOVED_TEMPORARILY)
end

local function fake(self)
    response.fake(self.body, self.headers)
end

local class = {}

-- 降级维度：按照请求的URI地址进行处理
-- 类型1、fake数据(接口级) 2、重定向(页面级)
function class:new(info)
    local instance = new_tab(0, 5)
    local t = info.type
    if t == "fake" and info.target then
        local targetObj = cjson.decode(info.target)
        if targetObj then
            if targetObj.headers then
                instance.headers = targetObj.headers
                instance.body = cjson.encode(targetObj.body)
            else
                instance.body = info.target
            end
        else
            instance.body = info.target
            instance.headers = {}
            instance.headers["Content-Type"] = "text/plain; charset = utf-8"
        end
        LOGGER(DEBUG, "return fake data")
        instance.doDegrade = fake
    elseif t == "redirect" and info.target then
        LOGGER(DEBUG, "redirect to ", info.target)
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