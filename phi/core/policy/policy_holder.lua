--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 20:31
-- 持有应用中定义的所有policy实例
--
local type = type
local require = require
local ipairs = ipairs
local setmetatable = setmetatable

local _M = {}

local LOGGER = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG

function _M:new(config)
    if type(config) == "table" then
        for _, name in ipairs(config) do
            local class = name:lower()
            LOGGER(ERR, "[POLICY_HOLDER]加载规则:" .. class)
            _M[class] = require("core.policy." .. class .. "_policy")
        end
    else
        LOGGER(ERR, "[POLICY_HOLDER]加载规则:" .. config)
        local path = config:lower()
        _M[path:lower()] = require("core.policy." .. path .. "_policy")
    end
    return setmetatable({}, { __index = _M })
end

function _M:calculate(policyType, arg, routerTable)
    if type(routerTable) ~= "table" then
        return nil, "路由表不是合法的lua表类型或者该表长度小于1！"
    end

    local policy = self[policyType]

    if not policy then
        return nil, "未查询到可用的路由规则:" .. policyType
    end

    local upstream, err = policy.calculate(arg, routerTable, self)

    -- 未查询到
    if err or not upstream then
        local defult = routerTable["default"]
        if defult then
            -- 但存在默认值
            LOGGER(DEBUG, "未匹配到合适的规则，返回存在的默认值，default:[" .. defult .. "]")
            upstream = defult
        else
            -- 不存在默认值
            LOGGER(DEBUG, "未匹配到合适的规则，并且未设置默认值！")
        end
    end

    return upstream, err
end

return _M