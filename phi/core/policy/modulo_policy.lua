--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 17:45
-- 对数字取模，以此选择对应的upstream
--
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR

local modulo_policy = {}

function modulo_policy.calculate(arg, routerTable)
    arg = tonumber(arg)
    if type(arg) ~= "number" then
        return nil, "输入的第一个参数必须为数字！" .. (arg or "nil")
    end
    local upstream, err;
    -- 遍历规则表，寻找正确匹配的规则
    -- 范围匹配规则：允许指定最小到最大值之间的请求路由到预定义的upstream中
    for up, policy in pairs(routerTable) do
        if policy ~= "number" and (policy < 0 or policy > 9) then
            return nil, "输入的第二个参数必须是数字且必须在0-9之间！"
        end
        if arg % 10 == policy then
            upstream = up
            LOGGER(DEBUG, "匹配到规则:", arg, ",modulo:[" .. policy .. "]")
            break
        end
        LOGGER(DEBUG, "未匹配的规则参数:", arg, ",modulo:[" .. policy .. "]")
    end
    return upstream, err
end

return modulo_policy