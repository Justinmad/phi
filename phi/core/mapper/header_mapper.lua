--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 17:55
-- 根据指定的头名称，获取头信息的值
--
local req_get_headers = ngx.req.get_headers
local _M = {}

function _M.map(_, header)
    return req_get_headers()[header]
end

return _M

