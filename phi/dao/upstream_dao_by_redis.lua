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
local ipairs = ipairs
local unpack = unpack
local type = type
local getn = table.getn
local insert = table.insert
local ceil = math.ceil
local gsub = string.gsub
local UPSTREAM_PREFIX = CONST.CACHE_KEY.UPSTREAM
local MATCH = UPSTREAM_PREFIX .. "*"
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local _M = {}
-- 查看指定upstream中的所有servers
-- @param routerKey：upstream名称
function _M:getUpstreamServers(upstream)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    local res, err = self.db:hgetall(cacheKey)
    local len = getn(res)
    local result = len ~= 0 and new_tab(0, len) or nil
    for i = 1, len, 2 do
        result[res[i]] = cjson.decode(res[i + 1]) or res[i + 1]
    end
    if err then
        LOGGER(ALERT, "通过upstream：[" .. upstream .. "]未查询到对应的服务器")
    end
    return result, err
end

-- 添加指定servers列表到upstream
-- @param upstream：upstream名称
-- @param servers：服务器列表 []
function _M:addUpstreamServers(upstream, servers)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    local commands = new_tab(0, getn(servers) * 2)
    for i, server in ipairs(servers) do
        commands[2 * i - 1] = server.name -- 主机名+端口
        commands[2 * i] = type(server.info) == "table" and cjson.encode(server.info) or server.info -- 具体信息的json字符串
    end
    local ok, err = self.db:eval([[
        local exists = redis.call('exists',KEYS[1])
        if exists == 0 then
            return redis.error_reply(table.concat({'upstream key[', KEYS[2] , '] is not exists'}))
        end
        return redis.call('hmset',KEYS[1],unpack(ARGV))
    ]], 2, cacheKey, upstream, unpack(commands))
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存服务器列表失败！err:", err)
    end
    return ok, err
end

-- 添加指定servers列表到upstream,如果已经存在会返回错误
-- @param upstream：upstream名称
-- @param servers：服务器列表 []
function _M:addOrUpdateUps(upstream, servers)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    local commands = new_tab(0, getn(servers) * 2)
    for i, server in ipairs(servers) do
        commands[2 * i - 1] = server.name -- 主机名+端口
        commands[2 * i] = type(server.info) == "table" and cjson.encode(server.info) or server.info -- 具体信息的json字符串
    end
    local ok, err = self.db:eval([[
        local exists = redis.call('exists',KEYS[1])
        if exists ~= 0 then
            redis.call('del',KEYS[1])
        end
        return redis.call('hmset',KEYS[1],unpack(ARGV))
    ]], 1, cacheKey, unpack(commands))
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]保存服务器列表失败！err:", err)
    end
    return ok, err
end

-- 删除指定upstream中的server
-- @param upstream：upstream名称
-- @param serverNames：服务器名称列表 [ip:port]
function _M:delUpstreamServers(upstream, serverNames)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    local ok, err = self.db:hdel(cacheKey, unpack(serverNames))
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]删除server失败！err:", err)
    end
    return ok, err
end

function _M:delUpstream(upstream)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    local ok, err = self.db:del(cacheKey)
    if not ok then
        LOGGER(ERR, "删除upstream：[" .. upstream .. "]失败！err:", err)
    end
    return ok, err
end

-- 修改指定upstream中的server
function _M:downUpstreamServer(upstream, serverName, down)
    local cacheKey = UPSTREAM_PREFIX .. upstream
    self.db:watch(cacheKey)
    local oldValue = self.db:hget(cacheKey, serverName)
    local oldTable = cjson.decode(oldValue) or oldValue
    oldTable.down = down
    self.db:multi()
    self.db:hset(cacheKey, serverName, cjson.encode(oldTable))
    local ok, err = self.db:exec()
    if not ok then
        LOGGER(ERR, "通过upstream：[" .. upstream .. "]修改server失败！err:", err)
    end
    return oldTable.weight, err
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
        local keys = res[2]
        self.db:init_pipeline(getn(keys))
        for _, k in ipairs(keys) do
            self.db:hgetall(k)
        end
        local results, err = self.db:commit_pipeline()
        if not results then
            LOGGER(ERR, "failed to commit the pipelined requests: ", err)
            return
        else
            for i, k in ipairs(keys) do
                local res = results[i]
                local len = getn(res)
                local ups = new_tab(0, 4)
                ups.servers = new_tab(0, ceil(len / 2))
                for c = 1, len, 2 do
                    local name = res[c]
                    if name == "strategy" or name == "mapper" or name == "tag" then
                        ups[res[c]] = res[c + 1]
                    else
                        -- TODO 未测试
                        local info = cjson.decode(res[c + 1])
                        if info then
                            info.name = res[c]
                            insert(ups.servers, info)
                        else
                            LOGGER(ERR, "bad upstream data !", res[c + 1])
                        end
                    end
                end
                result.data[gsub(k, UPSTREAM_PREFIX, "")] = ups
            end
        end
    else
        LOGGER(ERR, "全量查询失败！err:", err)
    end
    return result, err
end

local class = {}

function class:new(db)
    if db then
        return setmetatable({ db = db }, { __index = _M })
    end
    error("redis实例不能为nil,可能是PHI还未初始化？")
end

return class
