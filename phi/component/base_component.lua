--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 16:21
-- kong的插件扩展策略
-- @see https://github.com/Kong/kong/blob/master/kong
--

local Object = require "classic"

local BaseComponent = Object:extend()

local LOGGER = ngx.log
local DEBUG = ngx.DEBUG

function BaseComponent:new(name)
    self._name = name
end

function BaseComponent:init_worker()
    LOGGER(DEBUG, "executing component \"", self._name, "\": init_worker")
end

function BaseComponent:rewrite(ctx)
    LOGGER(DEBUG, "executing component \"", self._name, "\": rewrite")
end

function BaseComponent:access()
    LOGGER(DEBUG, "executing component \"", self._name, "\": access")
end

function BaseComponent:balance()
    LOGGER(DEBUG, "executing component \"", self._name, "\": balancer")
end

function BaseComponent:log()
    LOGGER(DEBUG, "executing component \"", self._name, "\": log")
end

return BaseComponent
