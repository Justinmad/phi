--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/29
-- Time: 14:57
-- 简单的mvc映射
--

local DEBUG = ngx.DEBUG
local INFO = ngx.INFO
local LOGGER = ngx.log
local Response = require "core.response"
local pretty = require 'pl.pretty'
local cjson = require 'cjson.safe'
local class = {}
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

local function doMapping(context, id, bean, realBean)
    local request_mapping = bean.request_mapping;
    request_mapping = mappingStrProcessor(request_mapping)
    local base_url = "/" .. (request_mapping or id)
    for k, v in pairs(bean) do
        -- 忽略_开始的函数，new函数，init函数，init_worker函数
        if k:find("_") ~= 1 and k ~= "new" and k ~= "init" and k ~= "init_worker" then
            -- 如果是函数，直接映射到路径
            local mapping
            local _self = realBean or bean
            if type(v) == "function" then
                mapping = base_url .. "/" .. k
                LOGGER(INFO, "mapping uri:[" .. mapping .. "] to handler:[" .. id .. "." .. k .. "]")
                context[mapping] = setmetatable({ anyMethod = true }, {
                    __call = function(self, req)
                        v(req, _self)
                    end
                })
            elseif type(v) == "table" and v.handler then
                -- 如果是表，按照表参数映射
                local hanler = v.handler
                if type(hanler) ~= "function" then
                    error("[" .. id .. "]中[" .. k .. "]非法的handler类型！type:" .. tostring(hanler))
                end
                if v.mapping then
                    mapping = base_url .. "/" .. mappingStrProcessor(v.mapping)
                else
                    mapping = base_url .. "/" .. k
                end
                -- 映射到对应的HTTP_METHOD
                local method = v.method
                if method then
                    if not context[mapping] then
                        context[mapping] = {}
                    end
                    LOGGER(INFO, "mapping uri:[" .. mapping .. "]-[" .. method .. "] to handler:[" .. id .. "." .. k .. "]")
                    context[mapping][method] = setmetatable({}, {
                        __call = function(self, req)
                            hanler(req, _self)
                        end
                    })
                else
                    LOGGER(INFO, "mapping uri:[" .. mapping .. "] to handler:[" .. id .. "." .. k .. "]")
                    context[mapping] = setmetatable({ anyMethod = true }, {
                        __call = function(self, req)
                            hanler(req, _self)
                        end
                    })
                end
            elseif k then
                LOGGER(DEBUG, "skip mapping field :[", k, "]")
            end
            -- 映射元表中的数据
            local meta_table = getmetatable(bean)
            if meta_table and meta_table.__index then
                doMapping(context, id, meta_table.__index, bean)
            end
        end
    end
end

local function mappingAll(context, applicationContext)
    for id, bean in pairs(applicationContext) do
        LOGGER(INFO, "begin to mapping bean:[" .. id .. "]")
        LOGGER(DEBUG, "bean structure:[" .. id .. "]:", pretty.write(bean))
        if bean.request_mapping then
            doMapping(context, id, bean)
        end
    end
end

local function parseRequest()
    local request = {}
    request.method = ngx.req.get_method():upper()
    request.uri = ngx.var.uri
    request.args = ngx.req.get_uri_args()
    request.headers = ngx.req.get_headers();
    if request.method ~= "GET" then
        ngx.req.read_body()
        request.request_body = ngx.req.get_body_data()
        local content_type = request.headers["Content-Type"]
        if content_type then
            if string.find(content_type, "json") then
                request.request_body = cjson.decode(request.request_body)
            elseif string.find(content_type, "x%-www%-form%-urlencoded") then
                local form_args = ngx.decode_args(request.request_body)
                setmetatable(request.args, { __index = form_args })
            end
        end
    end
    return request
end

function _M:content_by_lua()
    local request = parseRequest()

    local handler = self.context[request.uri]
    if not handler then
        Response.failure("Did not find handler method for given uri:[" .. request.uri .. "] and method:[" .. request.method .. "]", 404)
    else
        if not handler.anyMethod then
            handler = handler[request.method]
        end
        if handler then
            handler(request)
        end
    end
end

function class:init(applicationContext)
    local mvcContext = {}
    mappingAll(mvcContext, applicationContext)
    return setmetatable({ context = mvcContext }, { __index = _M })
end

return class
