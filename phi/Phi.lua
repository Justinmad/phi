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
-- 开启后可以检查未能被luajit所编译的代码
--local v = require "jit.v"
--v.on("/home/phi/logs/jit.log")

local instance = {
    -- 属性
    meta = meta,
    -- 配置
    configuration = {},
    -- 扩展组件
    components = {},
    -- 规则计算
    policy_holder = require("core.policy.policy_holder"),
    -- 请求映射
    mapper_holder = require("core.mapper.mapper_holder"),
    -- 事件总线
    observer = require("resty.worker.events"),
    -- 上下文，会将所有初始化的其他lua对象存放在context中，约定上下文中所有对象如果存在init_worker方法，都会在init_worker阶段自动执行
    context = require("core.application_context"),
    -- mvc容器
    admin = require("core.phi_mvc"),
    router = require("core.router"),
    balancer = require("core.balancer")
}

-- 代码预热，初始化通用lua对象
function instance:init()
    require("core.init")(instance)
end
-- worker特定lua对象初始化，如事件总线
function instance:init_worker()
    require("core.init_worker")(instance)
end
-- 处理balancer阶段，主要指upstream中的balancer_by_lua指令
function instance.balancer()
    local ctx = ngx.ctx
    -- 负载均衡
    self.balancer:balance(ctx)
    for _, c in ipairs(self.components) do
        c:balance()
    end
end
-- 处理rewrite阶段，主要指rewrite_by_luw指令
function instance:rewrite()
    local ctx = ngx.ctx
    -- 路由改写
    self.router:rewrite(ctx)
    -- 动态upstream映射
    self.balancer:load(ctx)
    for _, c in ipairs(self.components) do
        c:rewrite(ctx)
    end
end
function instance:access()
    for _, c in ipairs(self.components) do
        c:access()
    end
end
function instance:header_filter()
    local ctx = ngx.ctx
    for _, c in ipairs(self.components) do
        c:header_filter(ctx)
    end
end
-- 处理log阶段，主要指log_by_luw指令,log阶段是异步执行的，不会占用请求响应时间
function instance:log()
    local ctx = ngx.ctx
    local var = ngx.var
    for _, c in ipairs(self.components) do
        c:log(var, ctx)
    end
end

return instance
