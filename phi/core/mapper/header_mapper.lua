--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 17:55
-- 根据指定的头名称，获取头信息的值
--
local _M = {}

function _M.map(header)
    local field = "_cache_" .. header
    local result = ngx.ctx[field]

    if not result then
        result = ngx.req.get_headers()[header]
        if result then
            ngx.ctx[field] = result
        end
    end

    return result
end

return _M

