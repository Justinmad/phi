--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/30
-- Time: 15:13
-- 对db和shared缓存中的upstream列表的CRUD
--
local cjson = require "cjson"

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log

local ngx_upstream = require "ngx.upstream"
local get_servers = ngx_upstream.get_servers
local get_upstreams = ngx_upstream.get_upstreams

local CONST = require "core.constants"
local EVENTS = CONST.EVENT_DEFINITION.UPSTREAM_EVENTS
local PHI_UPSTREAM_DICT = CONST.DICTS.PHI_UPSTREAM

local SHARED_DICT = ngx.shared[PHI_UPSTREAM_DICT]

local class = {}
local _M = {}

function class:new(dao)
    return setmetatable({ dao = dao }, { __index = _M })
end

function _M:init()
    -- 加载配置文件中的upstream信息
end

function _M:init_worker(ev)
    self.observer = ev
    ev.register(function(data, event, source, pid)
        if ngx.worker.pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            upstream.set_peer_down(data[1], data[2], data[3], data[4])
            LOGGER(NOTICE, "received event; source=", source,
                ", event=", event,
                ", data=", tostring(data),
                ", from process ", pid)
        end
    end, EVENTS.SOURCE)
end

-- 需要通知其他worker进程peer状态改变
function _M:peerStateChangeEvent(upstreamName, isBackup, peerId, down)
    local event = down and EVENTS.PEER_DOWN or EVENTS.PEER_UP
    self.observer.post(EVENTS.SOURCE, event, { upstreamName, isBackup, peerId, down })
end

-- 动态添加upstream中的server
function _M:addUpstreamServer(upstream, servers)
    local ok, err
    -- 查询缓存
    local upstream = SHARED_DICT:get(upstream)
    -- 不存在或者非动态upstream
    if (not upstream) or upstream.dynamic then
        ok, err = self.dao:addUpstreamServer(upstream, servers)
        if ok then
            -- 存入共享缓存
            local serversStr = cjson.encode(servers)
            ok, err = SHARED_DICT:set(upstream, serversStr)
            -- 发布服务列表更新事件
            self.observer.post(EVENTS.SOURCE, EVENTS.SERVER_UPDATE, servers)
            if not ok then
                LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存server信息到shared_dict失败！err:", err)
            end
        end
    else
        err = "暂不支持对配置文件中的upstream进行编辑！"
    end
    return ok, err
end

-- 查询upstream中的所有server信息，包括shared缓存和配置文件中的所有数据
function _M:getUpstreamServers(upstream)
    local data = {}
    local upstreamInfo = SHARED_DICT:get(upstream)
    if upstreamInfo.stable then
        data["primary"] = ngx_upstream.get_primary_peers(upstream)
        data["backup"] = ngx_upstream.get_backup_peers(upstream)
    else
        data = upstreamInfo
    end
    return data
end

return class