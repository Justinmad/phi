--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/4
-- Time: 15:11
-- 定义了运行阶段的整体流程和生命周期,每个方法分别对应openresty中的lua执行阶段
-- 需要在init_by_lua阶段加载本项目，并保存为全局变量PHI
--
local Router = require "core.router"
local balancer = require "core.balancer"
local meta = require "meta"

local PHI = {
    meta = meta,
    configuration = nil,
    dao = nil,
    components = nil,
    policy_holder = nil,
    mapper_holder = nil
}

local router

-- 开启lua_code_cache情况下，每个worker只有一个Lua VM
-- require函数或者VM级别的变量（例如LRUCACHE）初始化应该在每个worker中都执行，而shared_DICT是跨worker共享的，那么初始化一次即可
-- 同时在init阶段初始化PHI实例，并进行了变量赋值，执行阶段的worker进程不能修改PHI的属性，这是resty的中避免全局变量被滥用的设计
function PHI:init()
    require "core.init"

    -- 组装PHI各个组件
    router = Router:new(PHI.configuration)
end

function PHI:init_worker()
    print("this is init_worker by lua block")
end

function PHI.balancer()
    balancer:exectue()
end

function PHI:rewrite()
    print("this is rewrite by lua block")
    ngx.var.backend = 'phi_upstream'
end

function PHI:access()
    router:access()
    print("this is access by lua block")
end

function PHI:log()
    print("this is log by lua block")
end

function PHI:handle_error()
    print("this is handle_error by lua block")
end

return PHI
