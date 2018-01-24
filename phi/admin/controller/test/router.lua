--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 14:10
-- To change this template use File | Settings | File Templates.
--

local _M = {}

local service = PHI.router_service
local Response = require "admin.response"

_M.del = {
    method = "get",
    mapping = "del",
    handler = function(request)
        local hostkey = request.uri_args["hostkey"]
        if hostkey then
            local ok, err = service.delRouterPolicy()
            if not ok then
                Response.failure(err)
            end
        end
    end
}

return _M
