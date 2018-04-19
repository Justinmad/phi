--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/29
-- Time: 14:57
-- 简单的mvc映射
--

local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local NOTICE = ngx.NOTICE
local INFO = ngx.INFO
local LOGGER = ngx.log

local setmetatable = setmetatable
local getmetatable = getmetatable
local pairs = pairs
local ipairs = ipairs
local type = type

local lor = require("lor.index")
local app = lor()
-- config
app:conf("view enable", true)
app:conf("view engine", "tmpl")
app:conf("view ext", "html")
app:conf("views", "../static")
-- error handle middleware
app:erroruse(function(err, req, res, next)
    LOGGER(ERR, err)
    local status = res.http_status
    res:status(200):json({
        status = { code = status, message = err, success = false },
        data = nil
    })
end)

local _M = {}
local function mappingStrProcessor(request_mapping)
    if request_mapping:find("/") == 1 then
        request_mapping = request_mapping:sub(2)
    end
    if request_mapping:sub(#request_mapping) == "/" then
        request_mapping = request_mapping:sub(#request_mapping)
    end
    return request_mapping
end

local function doMapping(context, id, bean)
    local request_mapping = bean.request_mapping or id;
    request_mapping = mappingStrProcessor(request_mapping)
    local base_url = "/" .. request_mapping
    local api_router = lor:Router()
    for k, v in pairs(bean) do
        -- 忽略_开始的函数，new函数，init函数，init_worker函数
        if k:find("_") ~= 1 and k ~= "new" and k ~= "init" and k ~= "init_worker" then
            -- 如果是函数，直接映射到路径
            local _self = (context and context[id]) or bean

            local mappingUrl, mappingMethods, mappingFunc

            if type(v) == "function" then
                mappingUrl = "/" .. k
                mappingFunc = function(req, res, next)
                    v(_self, req, res, next)
                end
            elseif type(v) == "table" and type(v.handler) == "function" then
                mappingFunc = function(req, res, next)
                    return v.handler(_self, req, res, next)
                end
                if v.mapping then
                    mappingUrl = "/" .. mappingStrProcessor(v.mapping)
                else
                    mappingUrl = "/" .. k
                end
                local method = v.method
                if type(method) == "string" then
                    mappingMethods = { method }
                elseif type(method) == "table" then
                    mappingMethods = method
                else
                    return LOGGER(ERR, "bad methods for handler:[" .. id .. "." .. k .. "]")
                end
            else
                LOGGER(NOTICE, "skip mapping field :[", k, "]")
            end
            if mappingUrl and mappingFunc then
                if not mappingMethods then
                    mappingMethods = { "get", "post" }
                end
                LOGGER(ERR, "mapped uri:[" .. base_url .. mappingUrl .. "]-[" .. table.concat(mappingMethods, ",") .. "] to handler:[" .. id .. "." .. k .. "]")
                for _, m in ipairs(mappingMethods) do
                    api_router[m](api_router, mappingUrl, mappingFunc)
                end
                -- 映射元表中的数据
                local meta_table = getmetatable(bean)
                if meta_table and meta_table.__index then
                    doMapping(context, id, meta_table.__index)
                end
            end
        end
    end
    app:use(base_url, api_router())
end

local function mappingAll(applicationContext)
    for id, bean in pairs(applicationContext) do
        local beanType = bean.__definition.type
        if beanType == "ctrl" or beanType == "CTRL" or beanType == "controller" or type(bean.request_mapping) == "string" then
            LOGGER(INFO, "begin to mapping bean:[" .. id .. "]")
            doMapping(applicationContext, id, bean)
        end
    end
end

function _M:content_by_lua()
    return app:run()
end

-- 做动态映射，方便扩展插件提供自己的api
function _M:mapping(base_path, apis)
    doMapping(nil, base_path, apis)
end

function _M:init(applicationContext)
    mappingAll(applicationContext)
    return setmetatable({ context = applicationContext }, { __index = _M })
end
return _M
