--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 14:37
-- 获取请求的uri,区别于ngx.var.request_uri，此uri不会包含任何路径参数
--
local ngx = ngx
local _M = {}

function _M.map(ctx, _)
    local u = ctx.__uri
    if not u then
        u = ngx.var.uri
        ctx.__uri = u
    end
    return u
end

return _M

