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
        "upstream_name_2":[from,"NONE"],  //小于from，需要使用NONE做占位符
        "upstream_name_3":["NONE",end]  //大于end，需要使用NONE做占位符
    }
--]]
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local tonumber = tonumber
local ipairs = ipairs
local type = type
local cjson = require("cjson.safe")

local range_policy = {}

function range_policy.calculate(arg, routerTable)
    local key = tonumber(arg)
    if not key then
        return nil, "输入的第一个参数必须为数字！" .. (arg or "nil")
    end
    local upstream, err
    -- 遍历规则表，寻找正确匹配的规则
    -- 范围匹配规则：允许指定最小到最大值之间的请求路由到预定义的upstream中
    for _, item in ipairs(routerTable) do
        local up, policy = item.result, item.expression
        if policy and type(policy) == "table" then
            local fromNum = tonumber(policy[1])
            local endNum = tonumber(policy[2])
            local selected = (fromNum == nil and type(endNum) == 'number' and key >= endNum) --gt
                    or (endNum == nil and type(fromNum) == 'number' and key <= fromNum) --lt
                    or (fromNum and endNum and key >= fromNum and key <= endNum)    -- between
            if selected then
                upstream = up
                LOGGER(DEBUG, key, "匹配到规则,range:[", fromNum, ",", endNum, "]")
                break
            end
            LOGGER(DEBUG, key, "未匹配到规则,range:[", fromNum, ",", endNum, "]")
        else
            err = "非法的规则表！"
            LOGGER(ERR, err, cjson.encode(routerTable))
        end
    end
    return upstream, err
end

return range_policy