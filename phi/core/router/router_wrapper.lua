--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/9
-- Time: 15:57
-- To change this template use File | Settings | File Templates.
local phi = require "Phi"
local mapper_holder = phi.mapper_holder
local policy_holder = phi.policy_holder

local setmetatable = setmetatable
local ipairs = ipairs
local ngx = ngx

local LOGGER = ngx.log
local NOTICE = ngx.NOTICE
local ERR = ngx.ERR

local _M = {}
function _M:route(ctx)
    -- 先取默认值
    local result = self.default
    -- 计算路由结果
    for _, t in ipairs(self.policies) do
        local tag
        if t.mapper then
            tag = mapper_holder:map(ctx, t.mapper)
        end
        local upstream, err = policy_holder:calculate(t.policy, tag, t.routerTable)
        if err then
            LOGGER(NOTICE, "Routing rules calculation err:", err)
        elseif upstream then
            result = upstream
            break
        end
    end
    if result then
        ctx.backend = result
        LOGGER(NOTICE, "will be routed to upstream:", result)
    end
end

local class = {}
function class:new(data)
    if not data.default then
        return nil, "default result must not be nil"
    end
    return setmetatable({
        default = data.default,
        policies = data.policies
    }, { __index = _M })
end

return class