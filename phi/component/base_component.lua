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

function BaseComponent:rewrite()
  LOGGER(DEBUG, "executing component \"", self._name, "\": rewrite")
end

function BaseComponent:access()
  LOGGER(DEBUG, "executing component \"", self._name, "\": access")
end

function BaseComponent:log()
  LOGGER(DEBUG, "executing component \"", self._name, "\": log")
end

return BaseComponent
