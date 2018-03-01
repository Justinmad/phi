--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 14:49
-- To change this template use File | Settings | File Templates.
--
local ngx = ngx
local _M = {}

function _M.map(ctx)
    local result = ctx.__host;
    if not result then
        -- 获取到请求头中的Host
        result = ngx.req.get_headers()['Host']
        if result then
            -- 获取到变量中的HostKey，则优先使用
            local hostkey = ngx.var.hostkey
            if hostkey then
                result = hostkey
            end
            ctx.__host = result;
        end
    end

    return result
end

return _M
