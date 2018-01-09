--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 17:32
-- To change this template use File | Settings | File Templates.
--
local utils = {}

local _M = {}
function _M.file_exists(path)

    local file = io.open(path, "rb")

    if file then file:close() end

    return file ~= nil
end


setmetatable(utils, { __index = _M })

return utils