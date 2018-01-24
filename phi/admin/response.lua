--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 20:14
-- To change this template use File | Settings | File Templates.
--
local responses = require "kong.responses"

local _M = {}
local function resp(code, success, message, data)
    responses.send_HTTP_OK({
        code = code,
        status = {
            success = success,
            message = message
        },
        data = data
    })
end

function _M.success(data, msg)
    resp(200, true, msg or "ok", data)
end

function _M.failure(msg, code, data)
    resp(code or 200, false, msg or "ok", data)
end

return _M