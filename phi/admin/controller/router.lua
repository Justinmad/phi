--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 14:10
-- 路由api,提供路由的增删改查接口
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

--[[
    根据主机名称删除指定路由规则
    请求路径：/router/del
    请求方式：GET
    数据格式：hostkey=xxx
]] --
_M.del = {
    method = GET,
    mapping = "del",
    handler = function(request)
        local hostkey = request.uri_args["hostkey"]
        local ok, err
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
--[[
    添加路由规则，请求格式为json
    请求路径：/router/add
    请求方式：POST
    数据格式：
    {
        hostkey:"",
        data:{
            default:"",
            policies:""
        }
    }
]] --
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
        local ok, err = service:setRouterPolicy(hostkey, request.data)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

--[[
    根据hostkey查询路由规则，也可以起到提前加载缓存的目的
    请求路径：/router/get
    请求方式：GET
    数据格式：hostkey=xxx
 ]]
_M.get = {
    method = GET,
    handler = function(request)
        local hostkey = request.uri_args["hostkey"]
        local policies, err
        if hostkey then
            policies, err = service:getRouterPolicy(hostkey)
            if policies then
                Response.success(policies)
            end
        else
            err = "hostkey不能为空！"
        end
        Response.failure(err)
    end
}
--[[
    查询所有路由规则
    请求路径：/router/getAll
    请求方式：GET
    数据格式：cursor=0&count=10
    首次查询cursor请输入0，响应数据中会包含当前指针cursor的值，下次查询请传递此参数到服务器端，以此进行分页
 ]]
_M.getAll = {
    method = GET,
    handler = function(request)
        local cursor = request.uri_args["cursor"]
        local count = request.uri_args["count"]
        local res, err = service:getAllRouterPolicy(cursor, count)
        if err then
            Response.failure(err)
        end
        Response.success(res)
    end
}

return _M
