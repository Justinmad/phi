--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/8
-- Time: 17:12
-- To change this template use File | Settings | File Templates.
--
--[[
    一个符合要求的范围匹配的规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "upstream_name_1":"1", //匹配前缀为1的请求
        "upstream_name_2":"2",  //匹配前缀为2的请求
        "upstream_name_3":"30"  //匹配前缀为30的请求
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ipairs = ipairs
local sub = string.sub
local string_len = string.len

local suffix_policy = {}

function suffix_policy.calculate(arg, routerTable)
    local upstream, err;
    if arg then
        local argLength = string_len(arg)
        -- 遍历规则表，寻找正确匹配的规则
        -- 范围匹配规则：允许符合后缀名的请求路由到预定义的upstream中
        for _, item in ipairs(routerTable) do
            local up, policy = item.ups, item.policy
            local policyLength = string_len(policy)
            if argLength >= policyLength then
                local selected = sub(arg, 1, policyLength) == policy
                if selected then
                    upstream = up
                    LOGGER(DEBUG, "参数[", arg, "]匹配到规则,prefix:[", policy, "]")
                    break
                else
                    LOGGER(DEBUG, "参数[", arg, "]未匹配到规则,prefix:[", policy, "]")
                end
            end
        end
    end
    return upstream, err
end

return suffix_policy

