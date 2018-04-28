--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/25
-- Time: 14:48
-- To change this template use File | Settings | File Templates.
--
local resty_roundrobin = require "resty.roundrobin"
local phi = require "Phi"
local response = require "core.response"
local setmetatable = setmetatable
local mapper_holder = phi.mapper_holder

local ok, resty_chash = pcall(require, "resty.chash")
if not ok then
    resty_chash = require "core.balancer.simple_hash"
end

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local LOGGER = ngx.log
local ERR = ngx.ERR

local _M = {}

function _M:find(ctx)
    if self.mapper then
        local tag, err = mapper_holder:map(ctx, self.mapper)
        if err or not tag then
            LOGGER(ERR, "failed to calculate the hash ，mapper: ", self.mapper, "，tag：", self.tag)
            return response.failure("Failed to calculate the hash :-(", 500)
        end
        return self.balancer:find(tag)
    else
        return self.balancer:find()
    end
end

function _M:set(id, weight)
    self.balancer:set(id, weight)
end

local SKIP_INSTANCE = {
    find = function()
    end
}

local class = {}

function class:new(res)
    if res.notExists then
        return SKIP_INSTANCE
    end

    local server_list = new_tab(0, #res)
    local strategy, mapper
    for k, v in pairs(res) do
        if k == "strategy" then
            strategy = v
        elseif k == "mapper" then
            mapper = v
        elseif type(v) == "table" then
            if v.down then
                server_list[k] = tonumber(v.weight) or 1
            end
        end
    end

    local balancer
    if strategy == "resty_chash" then
        if not mapper_holder[mapper] then
            return nil, "can't create balancer , bad mapper name :" .. mapper
        end
        balancer = resty_chash:new(server_list)
    elseif strategy == "roundrobin" then
        balancer = resty_roundrobin:new(server_list)
    else
        return nil, "can't create balancer , bad strategy type :" .. strategy
    end
    if mapper == "" or mapper == nil then
        mapper = nil
    elseif not mapper_holder[mapper] then
        return nil, "can't create balancer , bad mapper name :" .. mapper
    end
    return setmetatable({
        balancer = balancer,
        mapper = mapper
    }, { __index = _M })
end

return class