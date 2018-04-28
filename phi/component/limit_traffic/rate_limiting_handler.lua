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
    self.super.new(self, "rate-limiting")
    self.order = config.order
    self.service = ref
    return self
end

function rate_limiting_handler:rewrite(ctx)
    self.super.rewrite(self)
    local hostkey = get_host(ctx)
    local limiter, err = self.service:getLimiter(hostkey)
    if err or (not limiter) then
        -- 查询出现错误，放行
        LOGGER(ERR, "failed to get limiter by hostkey :", hostkey, ",err : ", err)
    else
        print(require("pl.pretty").write(limiter))
        limiter:incoming(ctx, true)
    end
end

function rate_limiting_handler:log(ctx)
    self.super.log(self)
    local leaving_func = ctx.leaving
    if type(leaving_func) == "function" then
        LOGGER(DEBUG, "record the connection leaving")
        leaving_func()
    end
end

return rate_limiting_handler