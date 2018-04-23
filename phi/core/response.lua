--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 20:14
-- To change this template use File | Settings | File Templates.
--
local responses = require "kong.responses"
local cjson = require "cjson.safe".new()
cjson.encode_empty_table_as_object(false)
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

local function resp_empty_empty_table_as_array(code, success, message, data)
    local content = {
        code = code,
        status = {
            success = success,
            message = message
        },
        data = data
    }
    local encoded, errMsg = cjson.encode(content)
    if not encoded then
        ngx.log(ngx.ERR, "[admin] could not encode value: ", errMsg)
    end
    ngx.say(encoded)
    return ngx.exit(200)
end

function _M.success(data, msg, encode_empty_table_as_array)
    if encode_empty_table_as_array then
        return resp_empty_empty_table_as_array(200, true, msg or "ok", data)
    end
    resp(200, true, msg or "ok", data)
end

function _M.failure(msg, code, data, encode_empty_table_as_array)
    if encode_empty_table_as_array then
        return resp_empty_empty_table_as_array(code or 200, false, msg or "error", data)
    end
    resp(code or 200, false, msg or "error", data)
end

function _M.fake(data)
    responses.send_HTTP_OK(data)
end

return _M