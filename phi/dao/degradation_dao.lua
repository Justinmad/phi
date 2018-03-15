--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/3/14
-- Time: 9:40
-- To change this template use File | Settings | File Templates.
--
local cjson = require "cjson.safe"
local CONST = require "core.constants"
local ipairs = ipairs
local getn = table.getn
local insert = table.insert
local type = type
local unpack = unpack
local gsub = string.gsub
local ceil = math.ceil

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log

local SERVICE_DEGRADATION_PREFIX = CONST.CACHE_KEY.SERVICE_DEGRADATION
local MATCH = SERVICE_DEGRADATION_PREFIX .. "*"

local _M = {}

function _M:getDegradations(hostkey)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local res, err = self.db:hgetall(cacheKey)
    local len = getn(res)
    local result = len ~= 0 and new_tab(0, len) or nil
    for i = 1, len, 2 do
        result[res[i]] = cjson.decode(res[i + 1]) or res[i + 1]
    end
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的降级信息")
    end
    return result, err
end

function _M:getDegradation(hostkey, uri)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local policiesStr, err = self.db:hget(cacheKey, uri)
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的降级信息")
    end
    return cjson.decode(policiesStr), err
end

function _M:enabled(hostkey, uri, enabled)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local data, err = self.db:eval([[
        local exists = redis.call('hexists',KEYS[1],KEYS[2])
        if exists == 0 then
            return redis.error_reply(table.concat({'host key[', KEYS[3] , '] or hash key [',KEYS[2],'] is not exists'}))
        else
            local res = redis.call('hget',KEYS[1],KEYS[2])
            local data = cjson.decode(res)
            data.enabled = ARGV[1]
            redis.call('hset',KEYS[1],KEYS[2],cjson.encode(data))
            return redis.call('hget',KEYS[1],KEYS[2])
        end
    ]], 3, cacheKey, uri, hostkey, enabled)
    return cjson.decode(data), err
end

--function _M:addDegradation(hostkey, uri, policy)
--    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
--    local ok, err = self.db:hset(cacheKey, uri, cjson.encode(policy))
--    if not ok then
--        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存降级信息失败！err:", err)
--    end
--    return ok, err
--end

function _M:addDegradations(hostkey, degradations)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local commands = new_tab(getn(degradations) * 2, 0)
    for _, server in ipairs(degradations) do
        insert(commands, server.uri)
        insert(commands, type(server.info) == "table" and cjson.encode(server.info) or server.info)
    end
    local ok, err = self.db:hmset(cacheKey, unpack(commands))
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存降级信息失败！err:", err)
    end
    return ok, err
end

function _M:delDegradation(hostkey, uri)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local ok, err = self.db:hdel(cacheKey, uri)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]删除降级信息失败！err:", err)
    end
    return ok, err
end

-- 全量查询路由规则
-- @param cursor：指针
-- @param match：匹配规则
-- @param count：查询数量
function _M:getAllDegradations(cursor, count)
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
                local degradations = new_tab(0, ceil(len / 2))
                for c = 1, len, 2 do
                    local uri = res[c]
                    local info = cjson.decode(res[c + 1])
                    degradations[uri] = info
                end
                result.data[gsub(k, SERVICE_DEGRADATION_PREFIX, "")] = degradations
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