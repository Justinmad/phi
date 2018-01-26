--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/25
-- Time: 18:04
-- To change this template use File | Settings | File Templates.
--

local _M = {}

local Response = require "admin.response"

local upstream = require "ngx.upstream"
local get_servers = upstream.get_servers
local get_upstreams = upstream.get_upstreams

local ERR = ngx.ERR
local LOGGER = ngx.log

_M.getAll = function()
    local data = {}
    local us = get_upstreams()
    for _, u in ipairs(us) do
        local srvs, err = get_servers(u)
        if not srvs then
            LOGGER(ERR, "failed to get servers in upstream ", u, " err :", err)
        else
            data[u] = srvs
        end
    end
    Response.success(data)
end

_M.getAllRuntimeInfo = function()
    local data = {}
    local us = get_upstreams()
    for _, u in ipairs(us) do
        data["primary"] = upstream.get_primary_peers(u)
        data["backup"] = upstream.get_backup_peers(u)
    end
    Response.success(data)
end

_M.getPrimaryPeers = function(request)
    local upstreamName = request.args["upstreamName"]
    if not upstreamName then
        Response.failure("upstreamName不能为空！")
    end
    local peers = upstream.get_primary_peers(upstreamName)
    Response.success(peers)
end

_M.getBackupPeers = function(request)
    local upstreamName = request.args["upstreamName"]
    if not upstreamName then
        Response.failure("upstreamName不能为空！")
    end
    local peers = upstream.get_backup_peers(upstreamName)
    Response.success(peers)
end

--[[
    从指定upstream中摘除指定后端server
    请求路径：/upstream/setPeerDown
    @param upstream_name:
    @param is_backup: 根据查询信息中返回的backup属性
    @param peer_id: 根据查询信息中返回的id属性
    @param down_value: true=关闭/false=开启
    TODO 添加事件支持，需要在修改成功后通知其他worker同步状态
-- ]]
_M.setPeerDown = function(request)
    local upstreamName = request.args["upstreamName"]
    local isBackup = request.args["isBackup"]
    local peerId = request.args["peerId"]
    local down = request.args["down"]
    if (not upstreamName) or (isBackup == nil) or (down == nil) or (not peerId) then
        Response.failure("缺少必须参数！")
    end

    local ok, err = upstream.set_peer_down(upstreamName, isBackup == "true", peerId, down == "true")
    if ok then
        Response.success()
    else
        Response.failue(err)
    end
end

return _M
