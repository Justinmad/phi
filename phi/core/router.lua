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
local lrucache = require "resty.lrucache"
local CONST = require "core.constants"
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local ALERT = ngx.ALERT
local NOTICE = ngx.NOTICE
local var = ngx.var
local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE

local class = {}
local _M = {}

function class:new(phi)
    local c, err = lrucache.new(phi.configuration.router_lrucache_size)
    _M.cache = c
    if not c then
        return error("failed to create the cache: " .. (err or "unknown"))
    end
    _M.service = phi.context["routerService"]
    _M.observer = phi.observer
    _M.policy_holder = phi.policy_holder
    _M.mapper_holder = phi.mapper_holder

    return setmetatable({}, { __index = _M })
end

function _M:init_worker(observer)
    -- 注册关注事件handler到指定事件源
    observer.register(function(data, event, source, pid)
        if event == EVENTS.DELETE then
            self.cache:set({ skipRouter = true })
        elseif event == EVENTS.UPDATE or event == EVENTS.CREATE then
            self.cache:set(data.hostkey, data.data)
        elseif event == "READ" then
            LOGGER(DEBUG, "received event; source=", source,
                ", event=", event,
                ", data=", tostring(data),
                ", from process ", pid)
        end
    end, EVENTS.SOURCE)
end

function _M.before()
end

-- 主要:根据host查找路由表，根据对应规则对本次请求中的backend变量进行赋值，达到路由到指定upstream的目的
function _M:access()
    local hostkey = utils.getHost();
    if hostkey then
        -- local缓存
        local rules, err = self.cache:get(hostkey)
        if not rules then
            -- shared缓存+db
            LOGGER(DEBUG, "worker缓存未命中，hostkey：", hostkey)
            rules, err = self.service:getRouterPolicy(hostkey)
            if err then
                LOGGER(ERR, "路由规则查询出现错误，err：", err)
            end
        else
            LOGGER(DEBUG, "worker缓存命中，hostkey：", hostkey)
        end
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
                var.backend = result
                LOGGER(NOTICE, "请求将被路由到，upstream：", result)
            end
        else
            LOGGER(ERR, err or ("路由规则格式错误，err：" .. tostring(rules)))
        end
    else
        LOGGER(ALERT, "hostkey为nil，无法执行路由操作")
    end
end

function _M.after()
end

return class