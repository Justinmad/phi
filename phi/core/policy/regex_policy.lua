--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/8
-- Time: 16:15
-- To change this template use File | Settings | File Templates.
--
--[[
    一个符合要求的范围匹配的规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "upstream_name_1":"regex1", //匹配符合正则regex1的请求
        "upstream_name_2":"regex2",  //匹配符合正则regex2的请求
        "upstream_name_3":"regex3"  //匹配符合正则regex3的请求
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local pairs = pairs
local find = ngx.re.find

local regex_policy = {}

function regex_policy.calculate(arg, routerTable)
    local upstream, err;
    if arg then
        for up, policy in pairs(routerTable) do
            local from, to
            from, to, err = find(arg, policy, "jo")
            if from then
                LOGGER(DEBUG, "参数[", arg, "]匹配到规则,", "regex:[", policy, "]")
                upstream = up
                break
            else
                LOGGER(DEBUG, "参数[", arg, "]未匹配的规则参数:[", policy, "]")
            end
        end
    end
    return upstream, err
end

return regex_policy

