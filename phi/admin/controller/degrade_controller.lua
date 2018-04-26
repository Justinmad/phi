--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/24
-- Time: 14:10
-- 路由api,提供降级信息的增删改查接口
--
--[[
    {
        method = "",
        uri = "",
        args = "",
        headers = "",
        body = ""
    }
--]]
local _M = {
    request_mapping = "degrade"
}
local Response = require "core.response"
local tonumber = tonumber
local CONST = require "core.constants"
local GET = CONST.METHOD.GET
local POST = CONST.METHOD.POST

_M.del = {
    method = GET,
    mapping = "del",
    handler = function(self, request)
        local hostkey = request.query.hostkey
        local uri = request.query.uri
        local ok, err
        if hostkey then
            ok, err = self.degradationService:delDegradation(hostkey, uri)
            if ok then
                return Response.success()
            end
        else
            err = "hostkey或者uri不能为空！"
        end
        return Response.failure(err)
    end
}

_M.add = {
    method = POST,
    handler = function(self, request)
        local body = request.body
        if not body then
            Response.failure("缺少请求参数,或者请求格式不正确！")
        end
        local hostkey = body.hostkey
        if not hostkey then
            Response.failure("hostkey不能为空！")
        end
        local infos = body.infos
        if not infos or #infos < 1 then
            Response.failure("infos不能为空！")
        end
        local ok, err = self.degradationService:addDegradations(hostkey, infos)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

_M.enabled = {
    method = GET,
    mapping = "enabled",
    handler = function(self, request)
        local hostkey = request.query["hostkey"]
        local uri = request.query["uri"]
        local enabled = request.query["enabled"]
        local ok, err
        if hostkey and uri and enabled ~= nil then
            ok, err = self.degradationService:enabled(hostkey, uri, enabled == "true")
            if ok then
                return Response.success()
            end
        else
            err = "hostkey或者uri不能为空！"
        end
        return Response.failure(err)
    end
}

_M.get = {
    method = GET,
    handler = function(self, request)
        local hostkey = request.query["hostkey"]
        local policies, err
        if hostkey then
            policies, err = self.degradationService:getDegradations(hostkey)
            if not err then
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
    请求路径：/degrade/getAll
    请求方式：GET
    数据格式：cursor=0&count=10
    首次查询cursor请输入0，响应数据中会包含当前指针cursor的值，下次查询请传递此参数到服务器端，以此进行分页
 ]]
_M.getAll = {
    method = GET,
    handler = function(self, request)
        local from = tonumber(request.query.from) or 0
        local count = tonumber(request.query.count) or 1024
        if from and count then
            local res, err = self.degradationService:getAllDegradations(from, count)
            if err then
                Response.failure(err)
            end
            Response.success(res)
        else
            Response.failure("缺少必须参数！")
        end
    end
}

return _M
