--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 16:11
-- 初始化数据，读取配置等等，提前加载一些模块以提高运行效率
--

-- 提前加载依赖，提高性能
require "resty.core"
local phi = require "Phi"
do
    local constants = require "core.constants"
    local LOGGER = ngx.log
    local ERR = ngx.ERR
    local function log(msg)
        LOGGER(ERR, msg)
    end

    local os = os.getenv("OS") or io.popen("uname -s"):read("*l")
    if os:match("[L|l]inux") then
        log("add linux lib/*.so to package cpath")
        package.cpath = "../openresty/?.so;../lib/?.so;;" .. package.cpath
    end

    -- 确认nginx配置中是否已经声明了程序运行时所必须的lua_shared_dict共享缓存
    for _, dict in pairs(constants.DICTS) do
        if not ngx.shared[dict] then
            return error("missing shared dict '" .. dict .. "' in Nginx " ..
                    "configuration, are you using a custom template? " ..
                    "Make sure the 'lua_shared_dict " .. dict .. " [SIZE];' " ..
                    "directive is defined.")
        end
    end

    log("------------------------PHI初始化开始------------------------")
    -- 加载配置
    local config, err = require "config.loader".load()
    if err then
        error("不能加载配置！err：" .. err)
    end
    phi.configuration = config
    -- 开启debug
    if config.debug then
        log("add mobdebug to package path")
        package.path = "../lib/debug/mobdebug/?.lua;../lib/debug/socket/?.lua;../lib/debug/?.lua;" .. package.path
        if os:match("[L|l]inux") then
            log("add linux lua socket lib to package cpath")
            package.cpath = "../lib/debug/clibs/?.so;" .. package.cpath
        else
            log("add windows lua socket lib to package cpath")
            package.cpath = "../lib/debug/clibs/?.dll;" .. package.cpath
        end
    end

    -- 加载计算规则
    phi.policy_holder = require "core.policy.policy_holder":new(config.enabled_policies)

    -- 加载Mapper规则
    phi.mapper_holder = require "core.mapper.mapper_holder":new(config.enabled_mappers)

    -- 初始化context
    local context = require "core.application_context":init(config.application_context_conf)
    phi.context = context

    -- 开启mio统计
    if config.enabled_mio then
        log("add mio to package path")
        package.path = "../lib/mio/?.lua;" .. package.path
        local mio = require("component.statistics.mio_handler"):new()
        context.mio = mio
    end

    -- bean init
    log("init bean")
    for _, bean in pairs(context) do
        if type(bean.init) == "function" then
            bean:init()
        end
    end

    -- 初始化components
    log("init components")
    local components = {}
    for _, bean in pairs(context) do
        if string.lower(bean.__definition.type or "") == "component" then
            table.insert(components, bean)
        elseif string.lower(bean.__definition.type or "") == "datasource" and phi.db == nil then
            phi.db = bean;
        end
    end

    -- 组件排序，所有的组件中order越大就有越高的优先级
    log("sort components")
    table.sort(components, function(c1, c2)
        local o1 = c1.order or 0
        local o2 = c2.order or 0
        return o1 > o2
    end)
    phi.components = components

    do
        local lor = require("lor.index")
        local app = lor()
        local router = require("api.router")

        -- routes
        app:conf("view enable", true)
        app:conf("view engine", "tmpl")
        app:conf("view ext", "html")
        app:conf("views", "../static")
        app:use(router())

        app:run()
    end

    -- 初始化admin规则
    if config.enabled_admin then
        log("enable phi admin")
        phi.admin = require "admin.phi_admin"
    end
    log("------------------------PHI初始化完成！------------------------")
end