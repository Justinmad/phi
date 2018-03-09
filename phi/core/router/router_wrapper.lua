--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/9
-- Time: 15:57
-- To change this template use File | Settings | File Templates.
--[[
    {
  "default": "phi_upstream",
  "policies": [
    {
      "order": 2,
      "policy": "range",
      "tag": "ip",
      "mapper": "ip",
      "routerTable": {
        "127.0.0.1:8001": [
          1,
          2
        ],
        "upstream7777_6666_5555": [
          29867477,
          29867477520
        ],
        "upstream9999": [
          100,
          1000
        ]
      }
    },
    {
      "default": "stable_upstream",
      "primary": {
        "order": 2,
        "tag": "ip",
        "mapper": "ip",
        "policy": "range_policy",
        "routerTable": {
          "secondary": [
            100,
            1000
          ],
          "upstream8888": [
            1001,
            2000
          ],
          "upstream7777_6666_5555": [
            "NONE",
            2100
          ]
        }
      },
      "secondary": {
        "order": 2,
        "tag": "ip",
        "mapper": "ip",
        "policy": "range_policy",
        "routerTable": {
          "upstream9999": [
            100,
            1000
          ],
          "upstream8888": [
            1001,
            2000
          ],
          "upstream7777_6666_5555": [
            "NONE",
            2100
          ]
        }
      }
    }
  ]
}
]] --
local phi = require "Phi"

local setmetatable = setmetatable
local ipairs = ipairs
local ngx = ngx

local LOGGER = ngx.log
local NOTICE = ngx.NOTICE

local _M = {}
function _M:route(ctx)
    -- 先取默认值
    local result = self.default
    -- 计算路由结果
    for _, t in ipairs(self.policies) do
        local tag
        if t.mapper then
            tag = self.mapper_holder:map(ctx, t.mapper, t.tag)
        end
        local upstream, err = self.policy_holder:calculate(t.policy, tag, t.routerTable)
        if err then
            LOGGER(NOTICE, "Routing rules calculation err:", err)
        elseif upstream then
            result = upstream
            break
        end
    end
    if result then
        ctx.backend = result
        LOGGER(NOTICE, "will be routed to upstream:", result)
    end
end

local class = {}
function class:new(data)
    if not data.default then
        return nil, "default result must not be nil"
    end
    return setmetatable({
        default = data.default,
        policies = data.policies,
        mapper_holder = phi.mapper_holder,
        policy_holder = phi.policy_holder
    }, { __index = _M })
end

return class