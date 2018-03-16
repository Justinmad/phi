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
    local os = os.getenv("OS") or io.popen("uname -s"):read("*l")
    if os:match("[L|l]inux") then
        package.cpath = "../openresty/?.so;../lib/?.so;;" .. package.cpath
    end
    local constants = require "core.constants"
    local LOGGER = ngx.log
    local DEBUG = ngx.DEBUG
    local function debug(msg)
        LOGGER(DEBUG, msg)
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

    debug("------------------------PHI初始化开始------------------------")
    -- 加载配置
    local config, err = require "config.loader".load()
    if err then
        error("不能加载配置！err：" .. err)
    end
    phi.configuration = config

    -- 加载计算规则
    phi.policy_holder = require "core.policy.policy_holder":new(config.enabled_policies)

    -- 加载Mapper规则
    phi.mapper_holder = require "core.mapper.mapper_holder":new(config.enabled_mappers)

    -- 初始化context
    local context = require "core.application_context":init(config.application_context_conf)
    phi.context = context

    -- 初始化components
    local components = {}
    for _, bean in pairs(context) do
        if string.lower(bean.__definition.type or "") == "component" then
            table.insert(components, bean)
        end
    end
    -- 组件排序，所有的组件中order越大就有越高的优先级
    table.sort(components, function(c1, c2)
        local o1 = c1.order or 0
        local o2 = c2.order or 0
        return o1 > o2
    end)
    phi.components = components

    -- 初始化admin规则
    if config.enabled_admin then
        phi.admin = require "admin.phi_admin"
    end
    debug("------------------------PHI初始化完成！------------------------")
end