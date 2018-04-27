--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/28
-- Time: 14:55
-- 服务降级
--
local base_component = require "component.base_component"
local get_host = require("utils").getHost
local get_uri = require("Phi").mapper_holder["uri"].map

local ERR = ngx.ERR
local LOGGER = ngx.log

local degradation_handler = base_component:extend()

function degradation_handler:new(ref, config)
    self.super.new(self, "service-degradation")
    self.order = config.order
    self.service = ref
    return self
end

-- 服务降级
function degradation_handler:rewrite(ctx)
    self.super.rewrite(self)
    local hostkey = get_host(ctx)
    local uri = get_uri(ctx)
    local isDegraded, degrader, err = ctx.degrade, self.service:getDegrader(hostkey, uri)
    if err then
        -- 查询出现错误，放行
        LOGGER(ERR, "failed to get degrader by key :", hostkey, uri, ",err : ", err)
    else
        if not isDegraded then
            -- 上文未触发降级，取全局开关
            isDegraded = degrader.enabled
        end
        if isDegraded then
            degrader:doDegrade(ctx)
        end
    end
end

return degradation_handler

