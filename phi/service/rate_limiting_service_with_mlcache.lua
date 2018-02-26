--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 15:46
-- 多级缓存的限流规则查询服务
--[[
    限流规则类型:
    req     限制请求速率
        {
            "rate"      : 200,      // 正常速率 200 req/sec
            "burst"     : 100,      // 突发速率 100 req/sec
            "mapper"    : "host",   // 限流flag
            "tag"       : "xxx"     // mapper函数的可选参数
            "rejected"  : "xxx"     // 拒绝策略
        }
    conn    限制并发连接数
        {
            "rate"      : 200,      // 正常速率 200 并发连接
            "burst"     : 100,      // 突发速率 100 并发连接
            "mapper"    : "host",   // 限流flag
            "tag"       : "xxx"     // mapper函数的可选参数
            "rejected"  : "xxx"     // 拒绝策略
        }
    traffic 组合限流，前两种的组合
]] --
local CONST = require "core.constants"
local LIMIT_REQ_DICT_NAME = CONST.PHI_LIMIT_REQ
local LIMIT_CONN_DICT_NAME = CONST.PHI_LIMIT_CONN

local _M = {
    limit_req = require "resty.limit.req",
    limit_conn = require "resty.limit.conn",
    limit_traffic = require "resty.limit.traffic"
}

function _M:new(dao, config)
    self.dao = dao
end

return _M


