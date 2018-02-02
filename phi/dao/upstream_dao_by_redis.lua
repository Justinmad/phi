--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/30
-- Time: 15:09
-- 主要负责通过redis对动态upstream以及动态server数据进行CRUD操作
-- 必须要实现以下几个方法
-- getUpstreamServers(upstream)
-- addUpstreamServers(upstream, servers)
-- delUpstreamServer(upstream, serverName)
-- getAllUpstreams(cursor, match, count)
--
local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log
local cjson = require "cjson.safe"
local CONST = require "core.constants"
local UPSTREAM_PREFIX = CONST.CACHE_KEY.UPSTREAM
local MATCH = UPSTREAM_PREFIX .. "*"

local _M = {}
-- 查看指定upstream中的所有servers
-- @param routerKey：upstream名称
function _M:getUpstreamServers(upstream)
    local cahcheKey = UPSTREAM_PREFIX .. upstream
    local policiesStr, err = self.db:hgetall(cahcheKey)
    if err then
        LOGGER(ALERT, "通过upstream：[" .. upstream .. "]未查询到对应的服务器")
    end
    return policiesStr, err
end

-- 添加指定servers列表到upstream
-- @param upstream：upstream名称
-- @param servers：服务器列表 []
function _M:addUpstreamServers(upstream, servers)
    local cahcheKey = UPSTREAM_PREFIX .. upstream
    local commands = {}
    for i, server in ipairs(servers) do
        commands[2 * i - 1] = server.name
        commands[2 * i] = server.info
    end
    local ok, err = self.db:hset(cahcheKey, unpack(servers))
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存服务器列表失败！err:", err)
    end
    return ok, err
end

-- 删除指定upstream中的server
-- @param routerKey：路由key
function _M:delUpstreamServer(upstream, serverName)
    local cahcheKey = UPSTREAM_PREFIX .. upstream
    local ok, err = self.db:hdel(cahcheKey, serverName)
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]删除server失败！err:", err)
    end
    return ok, err
end

-- 全量查询路由规则
-- @param cursor：指针
-- @param match：匹配规则
-- @param count：查询数量
function _M:getAllUpstreams(cursor, count)
    local res, err = self.db:scan(cursor, "MATCH", MATCH, "COUNT", count)
    local result
    if res then
        result = {
            cursor = res[1],
            data = {}
        }
        local kes = res[2]
        self.db:init_pipeline(#kes)
        for _, k in ipairs(kes) do
            self.db:hgetall(k)
        end
        local results, err = self.db:commit_pipeline()

        if not results then
            LOGGER(ERR, "failed to commit the pipelined requests: ", err)
            return
        else
            for i, k in ipairs(kes) do
                local res = results[i]
                if type(res) == "table" and res[1] == false then
                    result.data[k:sub(#UPSTREAM_PREFIX + 1)] = { error = true, message = res[2] }
                else
                    result.data[k:sub(#UPSTREAM_PREFIX + 1)] = cjson.decode(res)
                end
            end
        end
    else
        LOGGER(ERR, "全量查询失败！err:", err)
    end
    return result, err
end

local class = {}
function class:new(db)
    return setmetatable({ db = db }, { __index = _M })
end

return class
