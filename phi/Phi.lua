--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/4
-- Time: 15:11
-- 定义了运行阶段的整体流程和生命周期,每个方法分别对应openresty中的lua执行阶段
--

local PHI = {}

function PHI.init()
    require "cjson"
end

function PHI.init_worker()
    print("this is init_worker by lua block")
end

function PHI.balancer()
    local balancer = require "ngx.balancer"

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

function PHI.rewrite()
    print("this is rewrite by lua block");
    ngx.var.backend = 'phi_upstream';
end

function PHI.access()
    print("this is access by lua block");
end

function PHI.log()
    print("this is log by lua block")
end

function PHI.handle_error()
    print("this is handle_error by lua block");
end

return PHI;
