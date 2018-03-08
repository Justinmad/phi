--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 15:06
-- To change this template use File | Settings | File Templates.
-- 通用的处理字符后缀的规则，即输入字符，和规则表，返回对应结果
--[[
    一个符合要求的范围匹配的规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "upstream_name_1":"1", //匹配后缀为1的请求
        "upstream_name_2":"2",  //匹配后缀为2的请求
        "upstream_name_3":"30"  //匹配后缀为30的请求
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local pairs = pairs
local sub = string.sub

local suffix_policy = {}

function suffix_policy.calculate(arg, routerTable)
    local upstream, err;
    if arg then
        local argLength = #arg
        -- 遍历规则表，寻找正确匹配的规则
        -- 范围匹配规则：允许符合后缀名的请求路由到预定义的upstream中
        for up, policy in pairs(routerTable) do
            local policyLength = #policy
            if argLength >= policyLength then
                local selected = sub(arg, argLength - policyLength + 1) == policy
                if selected then
                    upstream = up
                    LOGGER(DEBUG, "参数[", arg, "]匹配到规则", ",suffix:[", policy, "]")
                    break
                else
                    LOGGER(DEBUG, "参数[", arg, "]未匹配到规则", ",suffix:[", policy, "]")
                end
            end
        end
    end
    return upstream, err
end

return suffix_policy

