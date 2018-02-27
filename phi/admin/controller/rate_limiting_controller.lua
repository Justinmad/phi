--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/27
-- Time: 14:35
-- To change this template use File | Settings | File Templates.
--
local Response = require "core.response"
local CONST = require "core.constants"
local GET = CONST.METHOD.GET
local POST = CONST.METHOD.POST

local _M = {
    request_mapping = "rate"
}

--[[
    根据主机名称删除指定路由规则
    请求路径：/rate/del
    请求方式：GET
    数据格式：hostkey=xxx
]] --
_M.del = {
    method = GET,
    mapping = "del",
    handler = function(self, request)
        local hostkey = request.args["hostkey"]
        local ok, err
        if hostkey then
            ok, err = self.rateLimitingService:delLimitPolicy(hostkey)
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
    请求路径：/rate/add
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
    handler = function(self, request)
        local body = request.body
        if not body then
            Response.failure("缺少请求参数,或者请求格式不正确！")
        end
        local hostkey = body.hostkey
        if not hostkey then
            Response.failure("hostkey不能为空！")
        end
        local policy = body.data

        if #policy > 1 then
            for _, p in policy do
                if not p.type then
                    Response.failure("必须设置限流规则类型！")
                end
            end
        else
            if not policy.type then
                Response.failure("必须设置限流规则类型！")
            end
        end

        local ok, err = self.rateLimitingService:setLimitPolicy(hostkey, policy)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

--[[
    根据hostkey查询限流规则，也可以起到提前加载缓存的目的
    请求路径：/rate/get
    请求方式：GET
    数据格式：hostkey=xxx
 ]]
_M.get = {
    method = GET,
    handler = function(self, request)
        local hostkey = request.args["hostkey"]
        local policies, err
        if hostkey then
            policies, err = self.rateLimitingService:getLimitPolicy(hostkey)
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
    请求路径：/rate/getAll
    请求方式：GET
    数据格式：cursor=0&count=10
    首次查询cursor请输入0，响应数据中会包含当前指针cursor的值，下次查询请传递此参数到服务器端，以此进行分页
 ]]
_M.getAll = {
    method = GET,
    handler = function(self, request)
        local from = request.args.from
        local count = request.args.count
        if from and count then
            local res, err = self.rateLimitingService:getAllLimitPolicy(from, count)
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