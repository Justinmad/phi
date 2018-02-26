--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/29
-- Time: 20:24
-- 动态upstream模块，由proxy_next_upstream 和 proxy_next_upstream_tries 配置指令来控制retry，balancer_by_lua* 会在 retry 的时候自动被重新调用
--
local balancer = require "ngx.balancer"

local LOGGER = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local ALERT = ngx.ALERT

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
            LOGGER(ERR, "upstream查询出现错误，err：", err)
        elseif type(upstreamBalancer) == "table" then
            upstream = self.default_upstream
            -- 获取cache中的负载均衡器
            ctx.balancer = upstreamBalancer
        end
    else
        LOGGER(ALERT, "upstream为nil，转发到默认upstream:", self.default_upstream)
    end
    ngx.var.backend = upstream or self.default_upstream
end

function _M:balance(ctx)
    local ups_balancer = ctx.balancer

    local server = ups_balancer:find(ctx)
    LOGGER(DEBUG, "select server:", server)
    local ok, err = balancer.set_current_peer(server)

    if not ok then
        LOGGER(ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
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