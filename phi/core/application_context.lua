--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/26
-- Time: 20:23
-- To change this template use File | Settings | File Templates.
--
local pl_config = require "pl.config"
local pretty = require "pl.pretty"
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local _M = {}

local function loadConf(beanDefinitions, location)
    local conf = pl_config.read(location)
    for id, definition in pairs(conf) do
        local class = require(definition.path)
        -- 没有new函数，将此脚本直接放入context
        if type(class.new) ~= "function" then
            context[id] = class
        else
            -- 存在new函数，暂存入beanDefinitions，等待创建
            beanDefinitions[id] = definition
        end
    end
end

local function createBean(id, beanDefinitions, inCreation, context)
    local definition = beanDefinitions[id]
    if type(definition) ~= "table" then
        error("Error creating bean with name '", id, "' the bean definition is not a valid table")
    end
    -- 依赖
    LOGGER(DEBUG, id, "is now in creation")
    local ref_ids = definition.constructor_refs
    if type(ref_ids) == "string" then
        ref_ids = { ref_ids }
    end

    local refs = {}
    if #ref_ids > 0 then
        inCreation[id] = true
        for _, ref_id in ipairs(ref_ids) do
            local ref = context[ref_id]
            if not ref then
                if inCreation[ref] then
                    error("Error creating bean with name '", id, "':bean is currently in creation: Is there an unresolvable circular reference? check [", ref, "]")
                end
                createBean(ref_id, beanDefinitions, inCreation, context)
            end
            refs[ref_id] = ref
        end
    end

    local class = require(definition.path)
    if definition.config then
        context[id] = class:new(definition.config, refs)
    else
        context[id] = class:new(refs)
    end
    LOGGER(DEBUG, id, " is created now")
    rable.remove(inCreation, id)
end

function _M.init(config_locations)
    local context = {}
    local beanDefinitions = {}
    if type(config_locations) == "table" and #config_locations > 0 then
        for _, location in ipairs(config_locations) do
            loadConf(beanDefinitions, location)
        end
    elseif type(config_locations) == "string" then
        loadConf(beanDefinitions, config_locations)
    else
        error("非法的配置文件路径！")
    end

    -- 创建bean
    local inCreation = {}
    for id, _ in pairs(beanDefinitions) do
        if context[id] then
            LOGGER(DEBUG, id, " is already in the context,skip it")
        else
            createBean(id, beanDefinitions, inCreation, context)
        end
    end

    -- Autowire
    for id, definition in pairs(beanDefinitions) do
        local autowire = definition.autowire
        if autowire then
            if type(autowire) == "string" then
                autowire = { autowire }
            end
            LOGGER(DEBUG, id, " need to autowire ", pretty.write(autowire, ","))
            local bean = context[id]
            for _, ref_id in autowire do
                bean[ref_id] = context[ref_id] or error(ref_id, " is not exists in the context, check it ")
            end
        else
            LOGGER(DEBUG, id, " autowire list is empty,skip it")
        end
    end

    -- init
    for _, bean in pairs(context) do
        if type(bean.init) == "function" then
            bean:init()
        end
    end
    return context
end

return _M
