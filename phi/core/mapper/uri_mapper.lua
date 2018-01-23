--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 14:37
-- 获取请求的uri,区别于ngx.var.request_uri，此uri不会包含任何路径参数
--
local _M = {}

function _M.map()
    local u = ngx.var.uri
    return u
end

return _M

