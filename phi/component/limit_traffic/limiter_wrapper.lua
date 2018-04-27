--
-- Created by IntelliJ IDEA.
-- User: young
-- Date: 18-2-26
-- Time: 下午9:31
-- 包装所有的limiter
--
local DICTS = require("core.constants").DICTS
local utils = require("utils")
local get_host = utils.getHost
local limit_conn = require "resty.limit.conn"
local limit_count = require "resty.limit.count"
local limit_req = require "resty.limit.req"
local limit_traffic = require "resty.limit.traffic"
local ant_path_match = require "tools.ant_path_matcher".match
local get_uri = require "Phi".mapper_holder["uri"].map
local response = require "core.response"
local pretty_write = require("pl.pretty").write
local phi = require "Phi"
local mapper_holder = phi.mapper_holder

local getn = table.getn
local concat = table.concat
local insert = table.insert
local remove = table.remove

local ipairs = ipairs
local type = type
local tonumber = tonumber
local setmetatable = setmetatable

local LIMIT_REQ_DICT_NAME = DICTS.PHI_LIMIT_REQ
local LIMIT_CONN_DICT_NAME = DICTS.PHI_LIMIT_CONN
local LIMIT_COUNT_DICT_NAME = DICTS.PHI_LIMIT_COUNT

local ngx = ngx
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local sleep = ngx.sleep

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local function getKeyFunc(self, ctx, mapper, uriPattern)
    -- 在uri存在的条件下，匹配一次uri，查询是否需要对此次请求进行限流
    if uriPattern and not ant_path_match(uriPattern, get_uri(ctx)) then
        return nil
    end
    local key = get_host(ctx)
    if mapper then
        local mappedKey, err = mapper_holder:map(ctx, mapper)
        if mappedKey == nil or err then
            return nil
        else
            local tmp = new_tab(2, 0)
            -- host
            insert(tmp, key)
            -- upstream_name
            insert(tmp, ctx.upstream_name)
            if type(mapper) == "table" then
                if getn(mapper) > 0 then
                    -- multi mapper
                    for _, m in ipairs(mapper) do
                        if type(m) == "string" then
                            -- mapper
                            insert(tmp, m)
                        else
                            -- mapper + tag
                            insert(tmp, m.type)
                            insert(tmp, m.tag)
                        end
                    end
                else
                    -- mapper + tag
                    insert(tmp, mapper.type)
                    insert(tmp, mapper.tag)
                end
            elseif type(mapper) == "string" then
                -- mapper
                insert(tmp, mapper)
            end
            -- mapped key
            insert(tmp, mappedKey)
            -- final a complete key like [www.sample.com:dynamic_ups:uri_args:uid:1001]
            key = concat(tmp, ":")
        end
    end
    LOGGER(DEBUG, "limit traffic key is ", key)
    return key
end

local function getTrafficLimiterKeyFunc(self, ctx)
    local policy = self.policy
    local res = new_tab(getn(policy), 0)
    for idx, func in ipairs(self.limiter.keys) do
        insert(res, func(self, ctx, policy[idx].mapper, policy[idx].uri))
    end
    return res
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

local SKIP_INSTANCE = {
    incoming = function(self)
        LOGGER(DEBUG, "skip limiter")
    end
}

local trafficLimiter = {}
function trafficLimiter:incoming(key)
    -- 跳过Key为空的限流器
    local tmp_limiter = new_tab(getn(self.limiters), 0)
    for idx, k in ipairs(key) do
        if k ~= nil then
            insert(tmp_limiter, self.limiters[idx])
        else
            remove(key, idx)
        end
    end
    return limit_traffic.combine(tmp_limiter, key)
end

local function createTrafficLimiter(policy)
    local err
    local len = getn(policy)
    if len < 2 then
        err = "create traffic limiter failed，at least 2 rules are required,find " .. len
        LOGGER(ERR, err)
        return nil, nil, err
    end
    local limiters = new_tab(len, 0)
    local keys = new_tab(len, 0)
    for _, p in ipairs(policy) do
        local ll, err = createLimiter(p)
        if err then
            return nil, nil, err
        end
        insert(limiters, ll)
        insert(keys, getKeyFunc)
    end

    local limiter = setmetatable({
        limiters = limiters,
        keys = keys
    }, { __index = trafficLimiter })

    local get_key = getTrafficLimiterKeyFunc

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
    local key = self:get_key(ctx, self.mapper, self.uri)
    if key == nil then
        return
    end
    local lim = self.limiter
    local delay, err = lim:incoming(key, commit)
    if not delay then
        if err == "rejected" then
            LOGGER(DEBUG, "rejected req for key \r\n", pretty_write(key))
            if self.rejected == "degrade" then
                ctx.degrade = true
                return
            else
                return response.failure("Limited access,Service Temporarily Unavailable,please try again later :-)", 503)
            end
        end
        LOGGER(ERR, "failed to limit req: ", err)
        return response.failure("failed to limit req :-( ", 500)
    end

    if delay >= 0.001 then
        LOGGER(DEBUG, "delay req for ", delay, " by key ", pretty_write(key))
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
            self.rejected = policy.rejected
            return self
        end
    elseif typeStr == "conn" then
        local conn = tonumber(policy.conn)
        local burst = tonumber(policy.burst)
        if conn and burst then
            local limiter = self.limiter
            limiter:set_conn(conn)
            limiter:set_burst(burst)
            self.rejected = policy.rejected
            return self
        end
    elseif typeStr == "count" then
        local rate = tonumber(policy.rate)
        local time_window = tonumber(policy.time_window)
        if rate and time_window then
            local ll
            ll, err = limit_count.new(LIMIT_COUNT_DICT_NAME, rate, time_window)
            self.limiter = ll
            self.rejected = policy.rejected
            return self
        end
    elseif typeStr == "traffic" then
        local ll, get_keys
        ll, get_keys, err = createTrafficLimiter(policy.policies)
        if not err then
            self.limiter = ll
            self.get_key = get_keys
            self.rejected = policy.rejected
            return self
        end
    end
    err = err or "update limiter err，bad policy !\r\n"
    LOGGER(ERR, err, pretty_write(policy))
    return nil, err
end

local class = {}

function class:new(policy)
    if policy.skip then
        return SKIP_INSTANCE
    end
    local limiter, get_key, err
    local typeStr = policy.type
    if typeStr == "traffic" then
        limiter, get_key, err = createTrafficLimiter(policy.policies)
    else
        limiter, err = createLimiter(policy)
        get_key = getKeyFunc
    end
    if err then
        return nil, err
    else
        return setmetatable({
            uri = policy.uri,
            type = typeStr,
            get_key = get_key,
            limiter = limiter,
            rejected = policy.rejected,
            mapper = policy.mapper,
            policy = policy.policies
        }, { __index = _M })
    end
end

return class