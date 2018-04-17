--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/4
-- Time: 15:11
-- 定义了运行阶段的整体流程和生命周期,每个方法分别对应openresty中的lua执行阶段
-- 需要在init_by_lua阶段加载本项目，并保存为全局变量PHI
--
local meta = require "meta"
local ngx = ngx
local ipairs = ipairs
local require = require
--local v = require "jit.v"
--v.on("/home/phi/logs/jit.log")

local instance = {
-- 属性
    meta = meta,
-- 配置
    configuration = nil,
-- 扩展组件
    components = nil,
-- DB
    db = nil,
-- 规则计算
    policy_holder = nil,
-- 请求映射
    mapper_holder = nil,
-- 事件总线
    observer = nil,
-- 上下文，会将所有初始化的其他lua对象存放在context中，约定上下文中所有对象如果存在init_worker方法，都会在init_worker阶段自动执行
    context = {},
-- mvc容器
    mvc = nil
}

local router, balancer, components
-- 开启lua_code_cache情况下，每个worker只有一个Lua VM
-- require函数或者VM级别的变量（例如LRUCACHE）初始化应该在每个worker中都执行，而shared_DICT是跨worker共享的，那么初始化一次即可
-- 同时在init阶段初始化PHI实例，并进行了变量赋值，执行阶段的worker进程不能修改PHI的属性，这是resty的中避免全局变量被滥用的设计
function instance:init()
    require "core.init"
    router = instance.context["router"]
    balancer = instance.context["balancer"]
    components = instance.components
end

function instance:init_worker()
    require "core.init_worker"
end

function instance.balancer()
    local ctx = ngx.ctx
    -- 负载均衡
    balancer:balance(ctx)
    for _, c in ipairs(components) do
        c:balance()
    end
end

function instance:rewrite()
    local ctx = ngx.ctx
    -- 路由
    router:before(ctx)
    router:access(ctx)
    router:after(ctx)
    -- 动态upstream映射
    balancer:load(ctx)

    for _, c in ipairs(components) do
        c:rewrite(ctx)
    end
end

function instance:access()
    for _, c in ipairs(components) do
        c:access()
    end
end

function instance:header_filter()
    local ctx = ngx.ctx
    for _, c in ipairs(components) do
        c:header_filter(ctx)
    end
end

function instance:log()
    local ctx = ngx.ctx
    local var = ngx.var
    for _, c in ipairs(components) do
        c:log(var, ctx)
    end
end

return instance
