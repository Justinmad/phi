--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 10:17
-- 管理控制台
--
local cjson = require "cjson.safe"
local Response = require "admin.response"
local _M = {}

local function register(context, method, uri, func)
    context[method][uri] = func
end

local function parseRequest()
    local request = {}
    request.method = ngx.req.get_method():upper()
    request.uri = ngx.var.uri
    request.uri_args = ngx.req.get_uri_args()
    request.headers = ngx.req.get_headers();
    if request.method ~= "GET" then
        ngx.req.read_body()
        request.request_body = ngx.req.get_body_data()
        local content_type = request.headers["Content-Type"]
        if content_type and string.find(content_type, "json") then
            request.request_body = cjson.decode(request.request_body)
        end
    end
    return request
end

function _M:get(uri, func)
    register(self, "GET", uri, func)
end

function _M:post(uri, func)
    register(self, "POST", uri, func)
end

function _M:content()
    local request = parseRequest()

    local handler = self[request.uri]

    if type(handler) == "table" then
        handler = handler[request.method]
    end
    if type(handler) == "function" then
        handler(request)
    else
        Response.failure("Did not find handler method for given uri:[" .. request.uri .. "] and method:[" .. request.method .. "]", 404)
    end
end

return _M