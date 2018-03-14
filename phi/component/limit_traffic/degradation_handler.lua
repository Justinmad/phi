--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/28
-- Time: 14:55
-- 服务降级
--
local base_component = require "component.base_component"
local get_host = require("utils").getHost
local get_uri = require("phi").mapper_holder["uri"].map
local response = require "core.response"

local ERR = ngx.ERR
local LOGGER = ngx.log

local degradation_handler = base_component:extend()

function degradation_handler:new(ref, config)
    degradation_handler.super.new(self, "service-degradation")
    degradation_handler.order = config.order
    degradation_handler.service = ref
    return degradation_handler
end

-- 服务降级
function degradation_handler:rewrite(ctx)
    local hostkey = get_host(ctx)
    local isDegraded, degrader, err = ctx.degraded, self.service:getDegrader(hostkey)
    if err then
        -- 查询出现错误，放行
        LOGGER(ERR, "failed to get degrader by hostkey :", hostkey, ",err : ", err)
    else
        if not isDegraded then
            -- 上文未触发降级，取全局开关
            isDegraded = degrader.enabled
        end
        if isDegraded then
            if not degrader.skip then
                -- 做降级处理 1、fake数据 2、重定向 3、内部请求
                degrader:doDegrade(ctx)
            else
                LOGGER(ERR, "Cannot perform a demotion strategy ,degrader is nil")
                response.failure("Cannot perform a degrade strategy :-(")
            end
        end
    end
end

return degradation_handler

