--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/29
-- Time: 20:24
-- 动态upstream模块
--
local lrucache = require "resty.lrucache"
local CONST = require "core.constants"
local balancer = require "ngx.balancer"
local ngx_upstream = require "ngx.upstream"

local LOGGER = ngx.log
local DEBUG = ngx.DEBUG
local ERR = ngx.ERR
local ALERT = ngx.ALERT
local NOTICE = ngx.NOTICE

local get_upstreams = ngx_upstream.get_upstreams

local utils = require "utils"
local EVENTS = CONST.EVENT_DEFINITION.UPSTREAM_EVENTS
local _M = {}

function _M:init()
    -- 加载配置文件中的upstream信息
    local us = get_upstreams()
    for _, u in ipairs(us) do
        self.cache:set(u, "stable")
    end
end

function _M:init_worker(observer)
    -- 关注ups更新
    observer.register(function(data, event, source, pid)
        if event == EVENTS.UPS_UPDATE then
            self.cache:set(data[1], data[2])
        elseif event == EVENTS.UPS_DEL then
            self.cache:delete(data[1])
        end
        LOGGER(DEBUG, "received event; source=", source,
            ", event=", event,
            ", data=", tostring(data),
            ", from process ", pid)
    end, EVENTS.UPS_SOURCE)
    -- 关注动态upstream中的server增删
    observer.register(function(data, event, source, pid)
        if event == EVENTS.SERVER_UPDATE then

            self.cache:set()
        elseif event == EVENTS.UPS_DEL then
            self.cache:delete(data[1])
        end
        LOGGER(DEBUG, "received event; source=", source,
            ", event=", event,
            ", data=", tostring(data),
            ", from process ", pid)
    end, EVENTS.SERVER_SOURCE)
    -- 关注动态upstream中的server启停
    observer.register(function(data, event, source, pid)
        if event == EVENTS.UPS_UPDATE then
            self.cache:set(data[1], data[2])
        elseif event == EVENTS.UPS_DEL then
            self.cache:delete(data[1])
        end
        LOGGER(DEBUG, "received event; source=", source,
            ", event=", event,
            ", data=", tostring(data),
            ", from process ", pid)
    end, EVENTS.DYNAMIC_PEER_SOURCE)
end

function _M:before()
end

-- 检查是否属于动态upstream，如果是路由到default_upstream中进行balance操作
function _M:load(ctx)
    local upstream = ctx.backend
    if upstream then
        -- local缓存
        local infos = self.cache:get(upstream)
        if not infos then
            -- shared缓存+db
            LOGGER(DEBUG, "worker缓存未命中，upstream：", upstream)
            local err
            infos, err = self.service:getUpstream(upstream)
            if err then
                LOGGER(ERR, "upstream查询出现错误，err：", err)
            end
        else
            LOGGER(DEBUG, "worker缓存命中，upstream：", upstream)
        end
        if infos ~= "stable" then
            upstream = self.default_upstream
        end
    else
        LOGGER(ALERT, "upstream为nil，无法执行upstream列表更新操作")
    end
    ngx.var.backend = upstream
end

function _M:balance()
    utils.getHost(ctx);
    -- well, usually we calculate the peer's host and port
    -- according to some balancing policies instead of using
    -- hard-coded values like below
    local host = "127.0.0.1"
    local port = 5555

    local ok, err = balancer.set_current_peer(host, port)

    if not ok then
        LOGGER(ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end
end

function _M:after()
end

local class = {}

function class:new(ref, config)
    local c, err = lrucache.new(config.upstream_lrucache_size)
    if not c then
        return error("failed to create the cache: " .. (err or "unknown"))
    end
    local instance = {}
    instance.cache = c
    instance.default_upstream = config.balancer_upstream_name
    instance.service = ref
    instance.policy_holder = PHI.policy_holder
    instance.mapper_holder = PHI.mapper_holder
    return setmetatable(instance, { __index = _M })
end

return class