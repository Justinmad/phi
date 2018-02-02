--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 16:11
-- 初始化数据，读取配置等等，提前加载一些模块以提高运行效率
--

-- 提前加载依赖，提高性能
require "resty.core"
require "cjson.safe"

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
    debug("********************开始加载配置********************")
    local config, err = require "config.loader".load()
    if err then
        error("不能加载配置！err：" .. err)
    end
    PHI.configuration = config

    -- 加载计算规则
    debug("********************初始化Policy*******************")
    PHI.policy_holder = require "core.policy.policy_holder":new(config.enabled_policies)
    debug("==================初始化Policy结束=================")

    -- 加载Mapper规则
    debug("********************初始化Mapper*******************")
    PHI.mapper_holder = require "core.mapper.mapper_holder":new(config.enabled_mappers)
    debug("==================初始化Mapper结束=================")

    -- 初始化context
    debug("********************初始化context*******************")
    PHI.context = require "core.application_context":init(config.application_context_conf)
    debug("==================初始化context结束=================")

    -- 初始化admin规则
    if config.enabled_admin then
        debug("********************初始化PHI-ADMIN*******************")
        PHI.admin = require "admin.phi_admin"
        debug("==================初始化PHI-ADMIN结束=================")
    end


    debug("------------------------PHI初始化完成！------------------------")
