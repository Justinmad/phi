--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 17:38
-- 通用的处理数字范围的规则，即输入数字，和规则表，返回对应结果
--[[
    一个符合要求的范围匹配的规则示例：
    {
        "default":"stable_upstream", // 在任何情况下都应该首先设置默认的upstream server
        "upstream_name_1":[from,end], //从from到end之间
        "upstream_name_2":[from,"NONE"],  //小于from
        "upstream_name_3":["NONE",end]  //大于end
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR

local range_policy = {}

function range_policy.calculate(arg, policyTable)
    if type(arg) ~= "number" then
        return nil, "输入的第一个参数必须为数字！"
    end
    if type(policyTable) ~= "table" or #policyTable <= 0 then
        return nil, "输入的第二个参数必须是lua表或者该表长度小于0！"
    end

    -- 遍历规则表，寻找正确匹配的规则
    -- 范围匹配规则：允许指定最小到最大值之间的请求路由到预定义的upstream中
    for up, policy in pairs(policyTable) do
        if policy and type(policy) == "table" then
            local fromNum = policy[1]
            local endNum = policy[2]
            local gt = type(fromNum) == 'string' and fromNum == "NONE" and type(endNum) == 'number' and arg > endNum
            local lt = type(endNum) == 'string' and endNum == "NONE" and type(fromNum) == 'number' and arg < fromNum
            local between = type(fromNum) == 'number' and type(endNum) == 'number' and arg > fromNum and arg < endNum
            if gt or lt or between then
                return up, nil
            end
            LOGGER(ERR, "非法的规则参数！", fromNum, endNum)
        else
            LOGGER(ERR, "非法的规则表！", policy)
        end
        local defult = policyTable["default"]
        if defult then
            LOGGER(DEBUG, "未匹配到合适的规则，返回存在的默认值，default:[" .. defult .. "]")
        end
    end
end

return range_policy