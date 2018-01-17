--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 17:57
-- 根据指定的uri参数名称，获取uri参数的值
--
local _M = {}

function _M.map(arg_name)
    local field = "_cache_" .. arg_name
    local result = ngx.ctx[field]

    if not result then
        result = ngx.req.get_uri_args()[arg_name]
        if result then
            ngx.ctx[field] = result
        end
    end

    return result
end

return _M

