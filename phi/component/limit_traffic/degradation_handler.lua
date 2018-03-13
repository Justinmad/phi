--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/28
-- Time: 14:55
-- 服务降级
--
local base_component = require "component.base_component"
local get_host = require("utils").getHost
local type = type
local response = require "core.response"

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local degradation_handler = base_component:extend()

function degradation_handler:new(ref, config)
    degradation_handler.super.new(self, "service-degradation")
    degradation_handler.order = config.order
    degradation_handler.service = ref
    return degradation_handler
end

-- 服务降级
function degradation_handler:rewrite(ctx)
    local isDegraded, degrader, err = ctx.degraded, nil, nil
    local hostkey = get_host(ctx)
    if isDegraded then
        -- 做降级处理 1、fake数据 2、重定向 3、内部请求
        local _
        _, degrader, err = getDegrader(hostkey)
    else
        isDegraded, degrader, err = getDegrader(hostkey)
    end

    if err then
        -- 查询出现错误，放行
        LOGGER(ERR, "failed to get degrader by hostkey :", hostkey, ",err : ", err)
    else
        if isDegraded then
            if degrader then
                degrader:content()
            else
                LOGGER(ERR, "Cannot perform a demotion strategy ,degrader is nil")
                response.failure("Cannot perform a demotion strategy :-(")
            end
        end
    end
end

function degradation_handler:log(ctx)
    local leaving_func = ctx.leaving
    if type(leaving_func) == "function" then
        LOGGER(DEBUG, "record the connection leaving")
        leaving_func()
    end
end

return degradation_handler

