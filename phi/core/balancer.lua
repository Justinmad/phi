--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/29
-- Time: 20:24
-- 动态upstream模块，由proxy_next_upstream 和 proxy_next_upstream_tries 配置指令来控制retry，balancer_by_lua* 会在 retry 的时候自动被重新调用
--
local balancer = require "ngx.balancer"
local response = require "core.response"

local type = type
local setmetatable = setmetatable

local ngx = ngx
local LOGGER = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local exit = ngx.exit
local re_sub = ngx.re.sub
local utils = require "utils"

local _M = {}

function _M:init()
end

function _M:before()
end

-- 检查是否属于动态upstream，如果是路由到default_upstream中进行balance操作
function _M:load(ctx)
    local upstream = ctx.backend
    if upstream then
        local upstreamBalancer, err = self.service:getUpstreamBalancer(upstream)
        if err then
            -- 查询出错
            LOGGER(ERR, "search upstream err：", err, "for upstream : ", upstream)
            return response.failure("Failed to load upstream balancer ,please try again latter :-(", 500)
        elseif upstream == self.default_upstream and upstreamBalancer == "stable" then
            -- 返回固定ups，但是却等于phi_upstream的占位ups
            LOGGER(ERR, "Failed to dispatch to backend: ups_balancer is nil,", "for upstream : ", upstream)
            return response.failure("Failed to dispatch to backend: ups_balancer is nil :-(", 500)
        elseif type(upstreamBalancer) == "table" then
            -- 动态upstream
            ctx.dynamic_ups = upstream
            upstream = self.default_upstream
            -- 获取cache中的负载均衡器
            ctx.balancer = upstreamBalancer
            ctx.upstream_name = upstream
        elseif upstreamBalancer ~= "ip:port" then
            -- 固定ups
            ctx.upstream_name = upstream
        end
    else
        LOGGER(ERR, "failed to load upstream balancer ,upstream is nil")
        return response.failure("Sorry,The domain you requested was denied access! :-(", 410)
    end
    local var = ngx.var
    var.backend = upstream
    if var.http_upgrade then
        var.upstream_connection = "upgrade"
    end
end

function _M:balance(ctx)
    local ups_balancer = ctx.balancer
    if ups_balancer then
        local server = ups_balancer:find(ctx)
        if server then
            LOGGER(DEBUG, "select server：", server)
            local ok, err = balancer.set_current_peer(server)
            if not ok then
                LOGGER(ERR, "failed to set the current peer: ", err)
                exit(500)
            end
        else
            LOGGER(ERR, "service unavailable for upstream: ", ctx.dynamic_ups)
            exit(503)
        end
    else
        LOGGER(ERR, "failed to dispatch to backend: ups_balancer is nil?")
        exit(500)
    end
end

function _M:header_filter(ctx)
    local ups_balancer = ctx.balancer
    local location = ngx.header.Location
    if ups_balancer and location then
        ngx.header.Location = re_sub(location, self.default_upstream, utils.getHost(ctx))
    end
end

function _M:after()
end

local class = {}

function class:new(ref, config)
    local instance = {}
    instance.default_upstream = config.balancer_upstream_name
    instance.service = ref
    return setmetatable(instance, { __index = _M })
end

return class