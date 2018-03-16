--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 10:17
-- 管理控制台
--
local phi = require("Phi")

local context = phi.context
if not context then
    error("PHI未初始化完成？")
end
local mvc = require 'core.phi_mvc'
return mvc:init(context)