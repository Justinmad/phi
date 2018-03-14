--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 14:49
-- To change this template use File | Settings | File Templates.
--
local get_host = require("utils").getHost
local _M = {}

function _M.map(ctx)
    return get_host(ctx)
end

return _M
