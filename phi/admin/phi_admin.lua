--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 10:17
-- 管理控制台
--
if not PHI then
    error("PHI未初始化完成？")
end
local context = PHI.context
local mvc = require 'core.phi_mvc'
return mvc:init(context)