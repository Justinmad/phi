--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 20:31
-- 持有应用中定义的所有policy实例
--
local _M = {}
local mt = { __index = _M }
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG

function _M:new(config)
    if type(config) == "table" then
        for _, name in ipairs(config) do
            local class = name:lower()
            LOGGER(DEBUG, "[POLICY_HOLDER]加载规则:" .. class)
            _M[class] = require("core.policy." .. class)
        end
    else
        LOGGER(DEBUG, "[POLICY_HOLDER]加载规则:" .. config)
        _M[config:lower()] = require("core.policy." .. config)
    end
    return setmetatable({}, mt)
end

function _M:calculate(type, arg, routerTable)
    local policy = self[type]
    return policy.calculate(arg, routerTable)
end

return _M