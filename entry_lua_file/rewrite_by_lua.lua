--
-- Created by IntelliJ IDEA.
-- User: young
-- Date: 18-3-11
-- Time: 下午2:00
-- To change this template use File | Settings | File Templates.
--
local phi = require('Phi')
local debug = phi.configuration.debug
local port = phi.configuration.debug_port
local host = phi.configuration.debug_host
if debug then
    require("mobdebug").start(host, port)
end
phi:rewrite()