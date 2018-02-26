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

local LIMIT_REQ_DICT_NAME = DICTS.PHI_LIMIT_REQ
local LIMIT_CONN_DICT_NAME = DICTS.PHI_LIMIT_CONN
local LIMIT_COUNT_DICT_NAME = DICTS.PHI_LIMIT_COUNT

local ERR = ngx.ERR
local LOGGER = ngx.log

local ok, new_tab = pcall(require, "table.new")
if not ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local _M = {}

local function connLeaving(ctx, lim, key, delay)
    if lim:is_committed() then
        if not ctx.finally_func then
            ctx.finally_func = {}
        else
            table.insert(ctx.finally_func, function()
                local conn, err = lim:leaving(key, delay)
                if not conn then
                    ngx.log(ngx.ERR,
                        "failed to record the connection leaving ",
                        "request: ", err)
                end
            end)
        end
    end
end

function _M:incoming(ctx, commit)
    local key = self.get_key(ctx)
    local lim = self.limiter

    local delay, err = lim:incoming(key or get_host(), commit)

    if not delay then
        -- TODO 考虑的降级策略
        if err == "rejected" then
            return ngx.exit(503)
        end
        LOGGER(ERR, "failed to limit req: ", err)
        return ngx.exit(500)
    end

    if delay >= 0.001 then
        ngx.sleep(delay)
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

--TODO 更新操作
function _M:update(policy)
    local typeStr = policy.type
    if typeStr == "req" then
    elseif typeStr == "conn" then
    elseif typeStr == "count" then
    elseif typeStr == "traffic" then
    end
end

local class = {}

local function createLimiter(policy)
    if typeStr == "req" then
        return limit_req:new(LIMIT_REQ_DICT_NAME, policy.rate, policy.burst)
    elseif typeStr == "conn" then
        return limit_conn:new(LIMIT_CONN_DICT_NAME, policy.rate, policy.burst)
    elseif typeStr == "count" then
        return limit_count:new(LIMIT_COUNT_DICT_NAME, policy.rate, policy.time_window)
    end
end

function class:new(policy)
    local mapper_holder = PHI.mapper_holder
    local get_key = function(ctx)
        return policy.mapper and mapper_holder:map(ctx, policy.mapper, policy.tag) or get_host(ctx)
    end
    local typeStr = policy.type
    local limiter

    if typeStr == "traffic" then
        local limiters = new_tab(0, #policy)
        local keys = new_tab(0, #policy)
        for _, p in ipairs(policy) do
            table.insert(limiters, createLimiter(p))
            table.insert(keys, function(ctx)
                return p.mapper and mapper_holder:map(ctx, p.mapper, p.tag) or get_host(ctx)
            end)
        end

        limiter = {
            incoming = function()
                return limit_traffic:combine(limiters, keys)
            end,
            limiters = limiters,
            keys = keys
        }

        get_key = function(ctx)
            local res = new_tab(0, #policy)
            for _, func in ipairs(keys) do
                table.insert(res, func(ctx))
            end
            return res
        end
    else
        limiter = createLimiter(policy)
    end
    return setmetatable({
        get_key = get_key,
        limiter = limiter
    }, { __index = _M })
end

return class