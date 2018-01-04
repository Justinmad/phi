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
    print("this is balancer by lua block");
end

function PHI.rewrite()
    print("this is rewrite by lua block");
    ngx.var.backend = '127.0.0.1:8001';
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
