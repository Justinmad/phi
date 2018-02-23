--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/6
-- Time: 16:33
-- 用来做路由控制，根据指定规则进行访问控制：如灰度发布等.
--[[
    一个标准的路由表规则数据结构,多级路由的情况下,会按照顺序依次寻找符合条件的路由目标：
    {
        "default":"",
        "policies":[
         {
            "tag":"uid",
            "mapper":"uri_args",//枚举值 header uri_args
            "policy":"range_policy",//枚举值 range_policy
            //规则表
            "routerTable":{
                "upstream9999":[100,1000],
                "upstream9999":[1001,2000],
                "upstream9999":[2001,2100]
            }
         }
        ]
    }
--]]

local utils = require "utils"
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local ALERT = ngx.ALERT
local NOTICE = ngx.NOTICE
local _M = {}

function _M.before(ctx)
end

-- 主要:根据host查找路由表，根据对应规则对本次请求中的backend变量进行赋值，达到路由到指定upstream的目的
function _M:access(ctx)
    local hostkey = utils.getHost(ctx);
    if hostkey then
        -- local缓存
        local rules, err = self.service:getRouterPolicy(hostkey)
        if not err and rules and type(rules) == "table" then
            if rules.skipRouter then
                return
            end
            -- 先取默认值
            local result = rules.default
            -- 计算路由结果
            for _, t in pairs(rules.policies) do
                local tag
                if t.mapper then
                    tag = self.mapper_holder:map(t.mapper, t.tag)
                end
                local upstream, err = self.policy_holder:calculate(t.policy, tag, t.routerTable)
                if err then
                    LOGGER(ERR, "路由规则计算出现错误，err：", err)
                elseif upstream then
                    result = upstream
                    break
                end
            end
            if result then
                ctx.backend = result
                LOGGER(NOTICE, "请求将被路由到，upstream：", result)
            end
        else
            LOGGER(ERR, "路由规则查询出现错误或者规则格式错误，err：", err, ", policies:", tostring(rules))
        end
    else
        LOGGER(ALERT, "hostkey为nil，无法执行路由操作")
    end
end

function _M.after(ctx)
end

local class = {}
function class:new(ref)
    local instance = {}
    instance.service = ref
    instance.policy_holder = PHI.policy_holder
    instance.mapper_holder = PHI.mapper_holder
    return setmetatable(instance, { __index = _M })
end

return class