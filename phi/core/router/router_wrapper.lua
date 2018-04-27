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
--local get_host = require("utils").getHost
local ngx = ngx
local INFO = ngx.INFO
local tab_sort = table.sort
local LOGGER = ngx.log
local NOTICE = ngx.NOTICE

local function skipRouter(self, ctx)
    return LOGGER(INFO, "skip router")
end

local SKIP_INSTANCE = {
    route = skipRouter
}

local _M = {}

function _M:route(ctx)
    -- 先取默认值
    local result = self.default
    -- 计算路由结果
    if self.policies then
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
    end
    if result then
        ctx.backend = result
        LOGGER(NOTICE, "will be routed to upstream:", result)
    end
end

local class = {}
function class:new(data)
    if data.skip then
        return SKIP_INSTANCE
    end
    if not data.default then
        return nil, "default result must not be nil"
    end
    if type(data.policies) == "table" then
        tab_sort(data.policies, function(r1, r2)
            local o1 = tonumber(r1.order) or 0
            local o2 = tonumber(r2.order) or 0
            return o1 > o2
        end)
    end
    return setmetatable({
        default = data.default,
        policies = data.policies
    }, { __index = _M })
end

return class