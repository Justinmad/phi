--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/8
-- Time: 17:20
-- To change this template use File | Settings | File Templates.
--
local LOGGER = ngx.log
local ERR = ngx.ERR
local ck = require "resty.cookie"
local _M = {}

function _M.map(ctx, cookieName)
    local cookie = ctx.__cookie
    if not cookie then
        local cookie, err = ck:new()
        if not cookie then
            LOGGER(ERR, err)
            return nil
        end
    end
    return cookie:get(cookieName)
end

return _M


