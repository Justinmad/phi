--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/25
-- Time: 18:04
-- 查询upstream信息，启停upstream中的server
--
local CONST = require "core.constants"
local POST = CONST.METHOD.POST

local _M = {
    request_mapping = "upstream"
}

local Response = require "core.response"

function _M:getAllRuntimeInfo()
    Response.success(self.upstreamService:getAllRuntimeInfo())
end

function _M:getUpstreamServers(request)
    local upstreamName = request.args.upstreamName
    if not upstreamName then
        Response.failure("upstream不能为空！")
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
    请求数据示例：{
        upstreamName:"a new upstream",
        servers:[{
            addr:"127.0.0.1:8989",
            weight:100,
            backup:false,
            down:true
        }]
    }
-- ]]
_M.addUpstreamServers = {
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
        for _, server in ipairs(servers) do
            if type(server.name) ~= "string" or (server.name ~= "strategy" and type(server.info) ~= "table") then
                Response.failure("请检查servers列表的数据格式，server.name必须是字符串" .. type(server.info))
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
    从指定upstream中摘除指定后端server
    请求路径：/upstream/setPeerDown
    @param upstream_name:
    @param is_backup: 根据查询信息中返回的backup属性
    @param peer_id: 根据查询信息中返回的id属性
    @param down_value: true=关闭/false=开启
-- ]]
function _M:setPeerDown(request)
    local upstreamName = request.args["upstreamName"]
    local isBackup = request.args["isBackup"]
    local peerId = request.args["peerId"]
    local down = request.args["down"]
    if (not upstreamName) or (isBackup == nil) or (down == nil) or (not peerId) then
        Response.failure("缺少必须参数！")
    end

    local ok, err = self.upstreamService:setPeerDown(upstreamName, peerId, down == "true", isBackup and isBackup == "true")
    if ok then
        Response.success()
    else
        Response.failue(err)
    end
end

return _M
