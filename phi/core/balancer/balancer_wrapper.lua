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

local ok, resty_chash = pcall(require, "resty.chash")
if not ok then
    resty_chash = require "core.balancer.simple_hash"
end

local LOGGER = ngx.log
local ERR = ngx.ERR

local _M = {}

function _M:find(ctx)
    if self.mapper then
        local tag, err = self.mapper_holder:map(ctx, self.mapper, self.tag)
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

local class = {}

function class:new(strategy, server_list, mapper, tag)
    local balancer
    if strategy == "resty_chash" then
        if not phi.mapper_holder[mapper] then
            return nil, "can't create balancer , bad mapper name :" .. mapper
        end
        balancer = resty_chash:new(server_list)
    elseif strategy == "roundrobin" then
        balancer = resty_roundrobin:new(server_list)
    else
        return nil, "can't create balancer , bad strategy type :" .. strategy
    end
    if mapper == "" or mapper == nil then
        mapper, tag = nil, nil
    elseif not phi.mapper_holder[mapper] then
        return nil, "can't create balancer , bad mapper name :" .. mapper
    end
    return setmetatable({
        balancer = balancer,
        mapper = mapper,
        tag = tag,
        mapper_holder = phi.mapper_holder
    }, { __index = _M })
end

return class