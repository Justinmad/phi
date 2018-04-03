--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 17:57
-- 根据指定的uri参数名称，获取uri参数的值
--
local ngx = ngx
local _M = {}

function _M.map(ctx, arg_name)
    if ctx.__args then
        return ctx.__args[arg_name]
    else
        local args = ngx.req.get_uri_args()
        ctx.__args = args
        return args[arg_name]
    end
end

return _M

