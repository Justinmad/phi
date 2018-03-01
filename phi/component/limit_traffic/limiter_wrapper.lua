--
-- Created by IntelliJ IDEA.
-- User: young
-- Date: 18-2-26
-- Time: 下午9:31
-- 包装所有的limiter
--
local DICTS = require("core.constants").DICTS
local get_host = require("utils").getHost
local limit_conn = require "resty.limit.conn"
local limit_count = require "resty.limit.count"
local limit_req = require "resty.limit.req"
local limit_traffic = require "resty.limit.traffic"
local response = require "core.response"
local phi = require "Phi"

local ipairs = ipairs
local insert = table.insert
local tonumber = tonumber
local setmetatable = setmetatable

local LIMIT_REQ_DICT_NAME = DICTS.PHI_LIMIT_REQ
local LIMIT_CONN_DICT_NAME = DICTS.PHI_LIMIT_CONN
local LIMIT_COUNT_DICT_NAME = DICTS.PHI_LIMIT_COUNT

local ERR = ngx.ERR
local LOGGER = ngx.log

local sleep = ngx.sleep
local exit = ngx.exit

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local function createLimiter(policy)
    local typeStr = policy.type
    if typeStr == "req" then
        return limit_req.new(LIMIT_REQ_DICT_NAME, policy.rate, policy.burst)
    elseif typeStr == "conn" then
        return limit_conn.new(LIMIT_CONN_DICT_NAME, policy.conn, policy.burst, policy.delay)
    elseif typeStr == "count" then
        return limit_count.new(LIMIT_COUNT_DICT_NAME, policy.rate, policy.time_window)
    else
        LOGGER(ERR, "create limiter failed，bad policy type：", typeStr)
        return exit(500)
    end
end

local function createTrafficLimiter(policy, mapper_holder)
    if #policy < 2 then
        LOGGER(ERR, "create traffic limiter failed，at least 2 rules are required,find ", #policy)
        return exit(500)
    end
    local limiters = new_tab(0, #policy)
    local keys = new_tab(0, #policy)
    for _, p in ipairs(policy) do
        insert(limiters, createLimiter(p))
        insert(keys, function(ctx)
            return p.mapper and mapper_holder:map(ctx, p.mapper, p.tag) or get_host(ctx)
        end)
    end

    local limiter = {
        incoming = function()
            return limit_traffic:combine(limiters, keys)
        end,
        limiters = limiters,
        keys = keys
    }

    local get_key = function(ctx)
        local res = new_tab(0, #policy)
        for _, func in ipairs(keys) do
            insert(res, func(ctx))
        end
        return res
    end

    return limiter, get_key
end

local function connLeaving(ctx, lim, key, delay)
    local var = ngx.var
    local latency = var.upstream_response_time or (tonumber(var.request_time) - delay)
    if lim:is_committed() then
        ctx.leaving = function()
            local conn, err = lim:leaving(key, latency)
            if not conn then
                LOGGER(ERR,
                    "failed to record the connection leaving ",
                    "request: ", err)
            end
        end
    end
end

local _M = {}

function _M:incoming(ctx, commit)
    local key = self.get_key(ctx)
    local lim = self.limiter

    local delay, err = lim:incoming(key or get_host(ctx), commit)

    if not delay then
        -- TODO 考虑的降级策略
        if err == "rejected" then
            return response.failure("Limited access,Service Temporarily Unavailable,please try again later :-)", 503)
        end
        LOGGER(ERR, "failed to limit req: ", err)
        return response.failure("failed to limit req :-( ", 500)
    end

    if delay >= 0.001 then
        sleep(delay)
    end

    if self.type == "conn" then
        connLeaving(ctx, lim, key, delay)
    elseif self.type == "traffic" then
        for i, l in ipairs(lim.limiters) do
            if self.type == "conn" then
                connLeaving(ctx, l, lim.keys[i], delay)
            end
        end
    end
end

function _M:update(policy)
    local typeStr = policy.type
    if typeStr == "req" then
        local limiter = self.limiter
        limiter:set_rate(policy.rate)
        limiter:set_burst(policy.burst)
    elseif typeStr == "conn" then
        local limiter = self.limiter
        limiter:set_conn(policy.conn)
        limiter:set_burst(policy.burst)
    elseif typeStr == "count" then
        self.limiter = limit_count.new(LIMIT_COUNT_DICT_NAME, policy.rate, policy.time_window)
    elseif typeStr == "traffic" then
        self.limiter = createTrafficLimiter(policy, self.mapper_holder)
    else
        LOGGER(ERR, "update limiter err，bad policy type:", typeStr)
    end
    policy.wrapper = nil
    return self
end

local class = {}

function class:new(policy)
    local mapper_holder = phi.mapper_holder
    local limiter, get_key
    local typeStr = policy.type
    if typeStr == "traffic" then
        limiter, get_key = createTrafficLimiter(policy, mapper_holder)
    else
        limiter = createLimiter(policy)
        get_key = function(ctx)
            return policy.mapper and mapper_holder:map(ctx, policy.mapper, policy.tag) or get_host(ctx)
        end
    end

    return setmetatable({
        type = typeStr,
        get_key = get_key,
        limiter = limiter,
        mapper_holder = mapper_holder
    }, { __index = _M })
end

return class