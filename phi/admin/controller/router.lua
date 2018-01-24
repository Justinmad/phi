--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 14:10
-- 路由api
--
--[[
    {
        method = "",
        uri = "",
        uri_args = "",
        headers = "",
        request_body = ""
    }
--]]
local _M = {}

local service = PHI.router_service
local Response = require "admin.response"
local CONST = require "core.constants"
local GET = CONST.METHOD.GET
local POST = CONST.METHOD.POST

_M.del = {
    method = GET,
    mapping = "del",
    handler = function(request)
        local ok, err
        local hostkey = request.uri_args["hostkey"]
        if hostkey then
            ok, err = service:delRouterPolicy(hostkey)
            if ok then
                Response.success()
            end
        else
            err = "hostkey不能为空！"
        end
        Response.failure(err)
    end
}

_M.add = {
    method = POST,
    handler = function(request)
        local request = request.request_body
        if not request then
            Response.failure("缺少请求参数,或者请求格式不正确！")
        end
        local hostkey = request.hostkey
        if not request.hostkey then
            Response.failure("hostkey不能为空！")
        end
        if not request.data.default then
            Response.failure("必须设置默认路由服务器！")
        end
        local policies = request.data.policies
        if not policies or #policies < 1 then
            Response.failure("policies不能为空！")
        end
        local ok, err = service:setRouterPolicy(hostkey, policies)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

return _M
