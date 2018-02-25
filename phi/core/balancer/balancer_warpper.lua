--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/25
-- Time: 14:48
-- To change this template use File | Settings | File Templates.
--
local resty_roundrobin = require "resty.roundrobin"
local ok, resty_chash = pcall(require, "resty.chash")
if not ok then
    resty_chash = require "core.balancer.simple_hash"
end


local LOGGER = ngx.log
local ERR = ngx.ERR

local _M = {}

function _M:find()
    if self.mapper then
        local tag, err = self.mapper_holder:map(self.mapper, self.tag)
        if err then
            LOGGER(ERR, "failed to calculate the hash ，mapper: ", self.mapper, "，tag：", self.tag)
            return ngx.exit(500)
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
    local balancer = strategy == "resty_chash" and resty_chash:new(server_list) or resty_roundrobin:new(server_list)
    return setmetatable({ balancer = balancer, mapper = mapper, tag = tag ,mapper_holder = PHI.mapper_holder}, { __index = _M })
end

return class