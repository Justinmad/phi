--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 17:57
-- 根据指定的uri参数名称，获取uri参数的值
--
local _M = {}

function _M.map(ctx, arg_name)
    return ngx.req.get_uri_args()[arg_name]
end

return _M

