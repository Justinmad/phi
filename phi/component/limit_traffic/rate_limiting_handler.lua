--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 14:27
-- 流量控制
--
local base_component = require "component.base_component"

local rate_limiting_handler = base_component:extend()

function rate_limiting_handler:new(ref,config)
    rate_limiting_handler.super.new(self, "rate-limiting")
    rate_limiting_handler.order = config.order
    rate_limiting_handler.service = ref
end

function rate_limiting_handler:access(ctx)
end

return rate_limiting_handler