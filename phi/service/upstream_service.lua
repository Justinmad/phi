--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/30
-- Time: 15:13
-- 查询db和shared缓存中的upstream列表
--
local ERR = ngx.ERR
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log

local upstream = require "ngx.upstream"
local get_servers = upstream.get_servers
local get_upstreams = upstream.get_upstreams

local CONST = require "core.constants"
local EVENTS = CONST.EVENT_DEFINITION.UPSTREAM_EVENTS
local PHI_UPSTREAM_DICT = CONST.DICTS.PHI_UPSTREAM

local SHARED_DICT = ngx.shared[PHI_UPSTREAM_DICT]

local class = {}
local _M = {}

function class:new(dao)
    return setmetatable({ dao = dao }, { __index = _M })
end

function class:init_worker(ev)
    self.observer = ev
end

-- 需要通知其他worker进程peer状态改变
function _M:peerStateChangeEvent(upstreamName, isBackup, peerId, down)
    local event = down and EVENTS.PEER_DOWN or EVENTS.PEER_UP
    self.observer.post(EVENTS.SOURCE, event, { upstreamName, isBackup, peerId, down })
end

function _M:addUpstreamServer(upstream, servers)
    local commands = {}
    for i, server in ipairs(servers) do
        commands[2 * i - 1] = server.name
        commands[2 * i] = server.info
    end
    local ok, err = self.db:hset(upstream, unpack(servers))
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存服务器列表失败！err:", err)
    end
    return ok, err
end

return class