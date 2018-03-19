--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 17:41
-- 组合规则，允许嵌套规则
-- 前途路由计算返回的结果，会首先在当前路由表中查询，如果查询到结果，继续计算，否则当做upstream结果返回
--
local LOGGER = ngx.log
local ERR = ngx.ERR
local unique_policy = {}
function unique_policy.calculate(_, routerTable, _)
    local result = routerTable.result or (routerTable[1] and routerTable[1].result)
    if not result then
        LOGGER(ERR, "empty result table ?")
    end
    return result
end

return unique_policy
