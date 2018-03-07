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
local pretty_write = require("pl.pretty").write
local phi = require "Phi"
local getn = table.getn

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

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local function createLimiter(policy)
    local typeStr = policy.type
    if typeStr == "req" then
        local rate = tonumber(policy.rate)
        local burst = tonumber(policy.burst)
        if rate and burst then
            return limit_req.new(LIMIT_REQ_DICT_NAME, rate, burst)
        end
    elseif typeStr == "conn" then
        local conn = tonumber(policy.conn)
        local burst = tonumber(policy.burst)
        local delay = tonumber(policy.delay)
        if conn and burst and delay then
            return limit_conn.new(LIMIT_CONN_DICT_NAME, conn, burst, delay)
        end
    elseif typeStr == "count" then
        local rate = tonumber(policy.rate)
        local time_window = tonumber(policy.time_window)
        if rate and time_window then
            return limit_count.new(LIMIT_COUNT_DICT_NAME, rate, time_window)
        end
    end
    local err = "create limiter failed，bad policy type or args ! \r\n"
    LOGGER(ERR, err .. pretty_write(policy))
    return nil, err
end

local function createTrafficLimiter(policy, mapper_holder)
    local err
    local len = getn(policy)
    if len < 2 then
        err = "create traffic limiter failed，at least 2 rules are required,find " .. len
        LOGGER(ERR, err)
        return nil, nil, err
    end
    local limiters = new_tab(0, len)
    local keys = new_tab(0, len)
    for _, p in ipairs(policy) do
        local ll, err = createLimiter(p)
        if err then
            return nil, nil, err
        end
        insert(limiters, ll)
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
    policy.wrapper = nil
    local err
    local typeStr = policy.type
    if typeStr == "req" then
        local rate = tonumber(policy.rate)
        local burst = tonumber(policy.burst)
        if rate and burst then
            local limiter = self.limiter
            limiter:set_rate(rate)
            limiter:set_burst(burst)
            return
        end
    elseif typeStr == "conn" then
        local conn = tonumber(policy.conn)
        local burst = tonumber(policy.burst)
        if conn and burst then
            local limiter = self.limiter
            limiter:set_conn(conn)
            limiter:set_burst(burst)
            return
        end
    elseif typeStr == "count" then
        local rate = tonumber(policy.rate)
        local time_window = tonumber(policy.time_window)
        if rate and time_window then
            local ll
            ll, err = limit_count.new(LIMIT_COUNT_DICT_NAME, rate, time_window)
            self.limiter = ll
            --            self.get_key = function(ctx)
            --                return policy.mapper and self.mapper_holder:map(ctx, policy.mapper, policy.tag) or get_host(ctx)
            --            end
            return
        end
    elseif typeStr == "traffic" then
        local ll, get_keys
        ll, get_keys, err = createTrafficLimiter(policy, self.mapper_holder)
        if not err then
            self.limiter = ll
            self.get_key = get_keys
            return
        end
    end
    err = err or "update limiter err，bad policy !\r\n"
    LOGGER(ERR, err, pretty_write(policy))
    return self, err
end

local class = {}

function class:new(policy)
    local mapper_holder = phi.mapper_holder
    local limiter, get_key, err
    local typeStr = policy.type
    if typeStr == "traffic" then
        limiter, get_key, err = createTrafficLimiter(policy, mapper_holder)
    else
        limiter, err = createLimiter(policy)
        get_key = function(ctx)
            return policy.mapper and mapper_holder:map(ctx, policy.mapper, policy.tag) or get_host(ctx)
        end
    end
    if err then
        return nil, err
    else
        return setmetatable({
            type = typeStr,
            get_key = get_key,
            limiter = limiter,
            mapper_holder = mapper_holder
        }, { __index = _M })
    end
end

return class