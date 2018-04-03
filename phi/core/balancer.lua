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

local find = ngx.re.find

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
            upstream = self.default_upstream
            -- 获取cache中的负载均衡器
            ctx.balancer = upstreamBalancer
        end
    else
        LOGGER(ERR, "failed to load upstream balancer ,upstream is nil")
        return response.failure("Sorry,The domain you requested was denied access! :-(", 410)
    end
    ngx.var.backend = upstream
end

function _M:balance(ctx)
    local ups_balancer = ctx.balancer
    if ups_balancer then
        local server = ups_balancer:find(ctx)
        LOGGER(DEBUG, "select server：", server)
        local ok, err = balancer.set_current_peer(server)
        if not ok then
            LOGGER(ERR, "failed to set the current peer: ", err)
            --            return response.failure("Failed to set the current peer :-(", 500)
            exit(500)
        end
    else
        LOGGER(ERR, "failed to dispatch to backend: ups_balancer is nil?")
        exit(500)
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