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
        local infos, err = self.service:getUpstream(upstream)
        if err then
            LOGGER(ERR, "upstream查询出现错误，err：", err)
        elseif type(infos) == "table" then
            upstream = self.default_upstream
            ctx.servers = infos
        end
    else
        LOGGER(ALERT, "upstream为nil，转发到默认upstream:", self.default_upstream)
    end
    ngx.var.backend = upstream or self.default_upstream
end

function _M:balance(ctx)
    local servers = ctx.servers
    print("-----------------------------------",require("pl.pretty").write(servers))
    -- 需要根据列表进行负载均衡处理
    -- well, usually we calculate the peer's host and port
    -- according to some balancing policies instead of using
    -- hard-coded values like below
    local host = "127.0.0.1"
    local port = 5555

    local ok, err = balancer.set_current_peer(host, port)

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
    instance.policy_holder = PHI.policy_holder
    instance.mapper_holder = PHI.mapper_holder
    return setmetatable(instance, { __index = _M })
end

return class