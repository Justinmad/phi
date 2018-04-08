--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/26
-- Time: 20:23
-- 读取配置文件，加载lua模块
--
local pl_config = require "pl.config"
local pretty_write = require "pl.pretty".write
local properties = require "Phi".configuration
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local INFO = ngx.INFO
local NOTICE = ngx.NOTICE
local pairs = pairs
local ipairs = ipairs
local require = require
local type = type
local error = error
local remove = table.remove
local str_sub = string.sub
local re_gsub = ngx.re.gsub
local re_find = ngx.re.find
local _M = {}

local function replaceProp(m)
    local result
    local prop = m[0]
    prop = str_sub(m[0], 3, #prop - 1)
    local from = re_find(prop, ":")
    if from then
        local key = str_sub(prop, 1, from - 1)
        local defaultValue = str_sub(prop, from + 1)
        result = properties[key] or defaultValue
        LOGGER(DEBUG, "replace placeholder str:[", key, "] with [", result, "]")
    else
        result = properties[prop]
        LOGGER(DEBUG, "replace placeholder str:[", prop, "] with [", result, "]")
    end
    return result
end

local function loadConf(context, beanDefinitions, location)
    local conf = pl_config.read(location)
    if conf then
        for id, definition in pairs(conf) do
            if context[id] or beanDefinitions[id] then
                error("Duplicate bean definition in config file:" .. location)
            else
                local class = require(definition.path)

                for k, v in pairs(definition) do
                    if type(v) == "string" then
                        local val = re_gsub(v, "(\\$\\{(\\w)+(:.+)*\\})", replaceProp, "joi")
                        local numResult = tonumber(val)
                        if numResult then
                            -- tonumber
                            val = numResult
                        elseif val == "true" or val == "false" then
                            -- toboolean
                            val = val == "true"
                        end
                        definition[k] = val
                    end
                end

                -- 没有new函数，将此脚本直接放入context
                if type(class.new) ~= "function" then
                    context[id] = class
                    class.__definition = definition
                    LOGGER(INFO, id, " is created now")
                else
                    -- 存在new函数，暂存入beanDefinitions，等待创建
                    beanDefinitions[id] = definition
                end
            end
        end
    else
        LOGGER(NOTICE, location .. " is not exists !")
    end
end

local function createBean(id, beanDefinitions, inCreation, context)
    local definition = beanDefinitions[id]
    if (type(definition) ~= "table") or not (definition.path) then
        error("Error creating bean with name '" .. id .. "' the bean definition is not exists")
    end
    -- 依赖
    LOGGER(DEBUG, id, " is now in creation")
    local ref_ids = definition.constructor_refs
    if type(ref_ids) == "string" then
        ref_ids = { ref_ids }
    end

    local refs
    if ref_ids and #ref_ids > 0 then
        refs = {}
        inCreation[id] = true
        for _, ref_id in ipairs(ref_ids) do
            local ref = context[ref_id]
            if not ref then
                if inCreation[ref] then
                    error("Error creating bean with name '" .. id .. "':bean is currently in creation: Is there an unresolvable circular reference? check [" .. ref .. "]")
                end
                createBean(ref_id, beanDefinitions, inCreation, context)
                ref = context[ref_id]
            end
            if ref then
                refs[ref_id] = ref
            else
                error(ref_id .. "is undefined , check it!")
            end
        end
        if #ref_ids == 1 then
            refs = refs[ref_ids[1]]
        end
    end
    local class = require(definition.path)
    local bean = class:new(refs or definition, definition)
    if not bean then
        error("error to create bean " .. id .. " ,the constructor return a " .. pretty_write(bean) .. " value")
    end
    bean.__definition = definition
    context[id] = bean
    LOGGER(INFO, id, " is created now")
    if inCreation[id] then
        local exists
        local inx = 0
        for k, _ in pairs(inCreation) do
            inx = inx + 1
            if k == id then
                exists = inx
                break
            end
        end
        if exists then
            remove(inCreation, exists)
        end
    end
end

function _M:init(configLocations)
    local context = {}
    local beanDefinitions = {}
    if type(configLocations) == "table" and #configLocations > 0 then
        for _, location in ipairs(configLocations) do
            loadConf(context, beanDefinitions, location)
        end
    elseif type(configLocations) == "string" then
        loadConf(context, beanDefinitions, configLocations)
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
    for id, bean in pairs(context) do
        local definition = bean.__definition
        local autowire = definition.autowire
        if autowire then
            if type(autowire) == "string" then
                autowire = { autowire }
            end
            LOGGER(DEBUG, id, " need to autowire ", pretty_write(autowire, ","))
            local bean = context[id]
            for _, ref_id in ipairs(autowire) do
                bean[ref_id] = context[ref_id] or error(ref_id .. " is not exists in the context, check it ")
            end
        else
            LOGGER(DEBUG, id, " autowire list is empty,skip it")
        end
    end

    return context
end

return _M
