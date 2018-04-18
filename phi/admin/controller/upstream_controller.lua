--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/25
-- Time: 18:04
-- 查询upstream信息，启停upstream中的server
--
local CONST = require "core.constants"
local type = type
local ipairs = ipairs
local insert = table.insert
local POST = CONST.METHOD.POST
local GET = CONST.METHOD.GET

local _M = {
    request_mapping = "upstream"
}

local Response = require "core.response"

function _M:getAllRuntimeInfo()
    Response.success(self.upstreamService:getAllRuntimeInfo())
end

function _M:getAllUpsInfo()
    Response.success(self.upstreamService:getAllUpsInfo())
end

function _M:getUpstreamServers(request)
    local upstreamName = request.query.upstreamName
    if not upstreamName then
        Response.failure("upstreamName不能为空！")
    end
    local res, err = self.upstreamService:getUpstreamServers(upstreamName)
    if res then
        Response.success(res)
    else
        Response.failure(err)
    end
end

--[[
    添加动态upstream
    请求路径：/upstream/addUpstreamServers
    请求方式：POST
    请求数据格式：JSON
    请求数据示例：
        {
            "upstreamName":"an exists upstream name",
            "servers":[{
              "name":"127.0.0.1:8989",
              "info":{
                  "weight":100
              }
            }]
        }
-- ]]
_M.addUpstreamServers = {
    method = POST,
    handler = function(self, request)
        local body = request.body
        if not body then
            Response.failure("缺少请求参数！".. body)
        end
        local upstreamName = body.upstreamName
        local servers = body.servers
         if not upstreamName or not servers then
            Response.failure("缺少必须的请求参数！")
        end
        if #(body.servers) < 1 then
            Response.failure("请至少指定一个server列表！")
        end
        for _, server in ipairs(servers) do
            if type(server.name) ~= "string" or server.name == "strategy" or server.name == "mapper" then
                Response.failure("请检查servers列表的数据格式是否正确!")
            end
        end
        local ok, err = self.upstreamService:addUpstreamServers(upstreamName, servers)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

--[[
    添加或者更新upstream
    请求路径：/upstream/addOrUpdateUps
    请求方式：POST
    请求数据格式：JSON
    请求数据示例：{
        upstreamName:"a new upstream",
        strategy:"resty_chash",
        mapper:"mapper",
        tag:"tag",
        servers:[{
            addr:"127.0.0.1:8989",
            weight:100,
            backup:false,
            down:true
        }]
    }
-- ]]
_M.addOrUpdateUps = {
    method = POST,
    handler = function(self, request)
        local body = request.body
        if not body then
            Response.failure("缺少请求参数！")
        end
        local upstreamName = body.upstreamName
        local strategy = body.strategy
        local mapper = body.mapper
        local servers = body.servers
        if not upstreamName or not servers or not strategy or not mapper then
            Response.failure("缺少必须的请求参数！")
        end
        if #(body.servers) < 1 then
            Response.failure("请至少指定一个server列表！")
        end
        for _, server in ipairs(servers) do
            if type(server.name) ~= "string" or (server.name == "strategy" or server.name == "mapper") or type(server.info) ~= "table" then
                Response.failure("请检查servers列表的数据格式是否正确!")
            end
        end
        insert(servers, { name = "strategy", info = strategy })
        insert(servers, { name = "mapper", info = mapper })
        local ok, err = self.upstreamService:addOrUpdateUps(upstreamName, servers)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

_M.delUps = {
    method = GET,
    handler = function(self, request)
        local upstreamName = request.query.upstreamName
        if not upstreamName then
            Response.failure("缺少必须的请求参数！upstreamName")
        end
        local ok, err = self.upstreamService:delUpstream(upstreamName)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

--[[
    添加动态upstream
    请求路径：/upstream/delUpstreamServers
    请求方式：POST
    请求数据格式：JSON
    请求数据示例：{
        upstreamName:"a new upstream",
        servers:["127.0.0.1:8989"]
    }
-- ]]
_M.delUpstreamServers = {
    method = POST,
    handler = function(self, request)
        local body = request.body
        local upstreamName = body.upstreamName
        local servers = body.servers
        if not body or not upstreamName or not servers then
            Response.failure("缺少必须的请求参数！")
        end
        if #(body.servers) < 1 then
            Response.failure("请至少指定一个server列表！")
        end
        local ok, err = self.upstreamService:delUpstreamServers(upstreamName, servers)
        if ok then
            Response.success()
        else
            Response.failure(err)
        end
    end
}

--[[
    从指定upstream中摘除指定后端server
    请求路径：/upstream/setPeerDown
    @param upstreamName:
    @param serverName: 根据查询信息中返回的id属性
    @param down: true=关闭/false=开启
-- ]]
function _M:setPeerDown(request)
    local upstreamName = request.query["upstreamName"]
    local peerId = request.query["serverName"]
    local down = request.query["down"]
    if (not upstreamName) or (down == nil) or (not peerId) then
        Response.failure("缺少必须参数！")
    end

    local ok, err = self.upstreamService:setPeerDown(upstreamName, peerId, down == "true")
    if ok then
        Response.success()
    else
        Response.failure(err)
    end
end

return _M
