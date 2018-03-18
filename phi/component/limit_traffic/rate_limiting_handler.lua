--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 14:27
-- 流量控制
--
local base_component = require "component.base_component"
local get_host = require("utils").getHost
local type = type

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local rate_limiting_handler = base_component:extend()

function rate_limiting_handler:new(ref, config)
    rate_limiting_handler.super.new(self, "rate-limiting")
    rate_limiting_handler.order = config.order
    rate_limiting_handler.service = ref
    return rate_limiting_handler
end

function rate_limiting_handler:rewrite(ctx)
    local hostkey = get_host(ctx)
    local limiter, err = self.service:getLimiter(hostkey)
    if err or (not limiter) then
        -- 查询出现错误，放行
        LOGGER(ERR, "failed to get limiter by hostkey :", hostkey, ",err : ", err)
    else
        if limiter.skip then
            LOGGER(DEBUG, "skip limiter for hostkey:", hostkey)
        else
            limiter:incoming(ctx, true)
        end
    end
end

function rate_limiting_handler:log(ctx)
    rate_limiting_handler.super.log(ctx)
    local leaving_func = ctx.leaving
    if type(leaving_func) == "function" then
        LOGGER(DEBUG, "record the connection leaving")
        leaving_func()
    end
end

return rate_limiting_handler