--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 17:41
-- 组合规则，允许嵌套规则
--
--[[
    一个符合要求的范围匹配的规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "policy_name_1":[from,end], //从from到end之间
        "policy_name_1":[from,"NONE"],  //小于from，需要使用NONE做占位符
        "policy_name_1":["NONE",end]  //大于end，需要使用NONE做占位符
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR

local range_policy = {}

function range_policy.calculate(_, routerTable, policyHolder)
    -- 遍历规则表
    for _, item in pairs(routerTable) do
        if item and type(item) == "table" then
            local tag = PHI.mapper_holder:map(item.mapper, item.tag)
            -- 是否应该有默认值?
            return policyHolder:calculate(item.policy, tag, item.routerTable)
        else
            local err = "非法的组合规则表！"
            LOGGER(ERR, err)
            return nil, err
        end
    end
end

return range_policy
