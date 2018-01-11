--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/6
-- Time: 17:02
-- 处理负载均衡流程
--
local balancer = require "ngx.balancer"

local _balancer = {}

local _M = {}

function _M.exectue()
    -- well, usually we calculate the peer's host and port
    -- according to some balancing policies instead of using
    -- hard-coded values like below
    local host = "127.0.0.1"
    local port = 8888

    local ok, err = balancer.set_current_peer(host, port)
    if not ok then
        ngx.log(ngx.ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end
end

setmetatable(_balancer, { __index = _M })

return _balancer