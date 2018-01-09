local Object = require "classic"

local BaseComponent = Object:extend()

local ngx_log = ngx.log
local DEBUG = ngx.DEBUG

function BaseComponent:new(name)
  self._name = name
end

function BaseComponent:init_worker()
  ngx_log(DEBUG, "executing component \"", self._name, "\": init_worker")
end

function BaseComponent:rewrite()
  ngx_log(DEBUG, "executing component \"", self._name, "\": rewrite")
end

function BaseComponent:access()
  ngx_log(DEBUG, "executing component \"", self._name, "\": access")
end

function BaseComponent:log()
  ngx_log(DEBUG, "executing component \"", self._name, "\": log")
end

return BaseComponent
