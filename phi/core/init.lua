--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 16:11
-- 初始化数据，读取配置等等，提前加载一些模块以提高运行效率
--

do
    local constants = require "core.constants"
    local LOGGER = ngx.log
    local DEBUG = ngx.DEBUG
    local function debug(msg)
        LOGGER(DEBUG, msg)
    end

    -- 确认nginx配置中是否已经声明了程序运行时所必须的lua_shared_dict共享缓存
    for _, dict in ipairs(constants.DICTS) do
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


    -- 初始化Redis
    debug("********************初始化Redis********************")
    local redis = require "tools.redis"
    local db = redis:new(config)
    local PhiDao = require "dao.phi_dao_by_redis"
    local phiDao, err = PhiDao:new(db)
    if err then
        error(err)
    else
        local RouterService = require "service.router_srevice"
        PHI.router_service = RouterService:new(phiDao)
    end
    debug("==================初始化Redis结束==================")


    -- 加载路由规则
    debug("********************初始化Policy*******************")
    PHI.policy_holder = require "core.policy.policy_holder":new(config.enabled_policies)
    debug("==================初始化Policy结束=================")


    -- 加载Mapper规则
    debug("********************初始化Mapper*******************")
    PHI.mapper_holder = require "core.mapper.mapper_holder":new(config.enabled_mappers)
    debug("==================初始化Mapper结束=================")

    debug("------------------------PHI初始化完成！------------------------")
end

-- 提前加载依赖，提高性能
require "resty.lrucache"
require "resty.core"
require "cjson.safe"