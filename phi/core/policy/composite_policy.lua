--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 17:41
-- 组合规则，允许嵌套规则
-- 前途路由计算返回的结果，会首先在当前路由表中查询，如果查询到结果，继续计算，否则当做upstream结果返回
--
--[[
    一个符合要求的组合路由规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "primary":{                  // primary规则是组合路由必须设置的属性
            "order":2,
            "tag": "ip",
            "mapper": "ip",
            "policy": "range_policy",
            "routerTable": {
                    "secondary": [100,
                    1000],
                    "upstream8888": [1001,
                    2000],
                    "upstream7777_6666_5555": ["NONE",
                    2100]
            }
        },
        "secondary":{               // secondary其他规则名称，可以随意指定，组合路由中primary计算的结果如果命中其他规则名称，则按照该规则再次进行计算
            "order":2,
            "tag": "ip",
            "mapper": "ip",
            "policy": "range_policy",
            "routerTable": {
                    "upstream9999": [100,
                    1000],
                    "upstream8888": [1001,
                    2000],
                    "upstream7777_6666_5555": ["NONE",
                    2100]
            }
        }
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR

local range_policy = {}

local function doCalculate(policyItem)
    local tag
    if policyItem.mapper then
        tag = PHI.mapper_holder:map(policyItem.mapper, policyItem.tag)
    end
    -- 计算路由
    return PHI.policy_holder[policyItem.policy].calculate(tag, policyItem.routerTable)
end

function range_policy.calculate(_, routerTable)
    local upstream, err
    local primary = routerTable.primary
    if primary and type(primary) == "table" then
        upstream, err = doCalculate(primary)
        if not err and upstream then
            -- 如果计算结果存在在当前的路由表中，则继续计算
            local secondary = routerTable[upstream]
            if secondary then
                LOGGER(DEBUG, "查询到组合路由表", secondary.policy, "继续计算！")
                upstream, err = doCalculate(secondary)
            end
        end
    else
        local err = "非法的组合规则表！"
        LOGGER(ERR, err)
    end
    return upstream, err
end

return range_policy
