--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 11:05
-- 主要负责从redis中加载路由数据
-- 必须要实现以下几个方法
-- getRouterPolicy(hostkey)
-- setRouterPolicy(hostkey, policy)
-- delRouterPolicy(hostkey)
-- getAllRouterPolicy(cursor, count)
--
local cjson = require "cjson.safe"
local CONST = require "core.constants"
local ipairs = ipairs
local type = type

local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log

local ROUTER_PREFIX = CONST.CACHE_KEY.ROUTER
local MATCH = ROUTER_PREFIX .. "*"

local _M = {}
-- 根据主机名查询路由规则表
-- @parma hostkey：路由key
function _M:getRouterPolicy(hostkey)
    local cacheKey = ROUTER_PREFIX .. hostkey
    local policiesStr, err = self.db:get(cacheKey)
    -- 查询db
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的路由规则")
    end
    return cjson.decode(policiesStr), err
end

-- 添加指定路由规则到db
-- @param hostkey：路由key
-- @param policy：规则数据,json串
function _M:setRouterPolicy(hostkey, policy)
    local cacheKey = ROUTER_PREFIX .. hostkey
    local ok, err = self.db:set(cacheKey, cjson.encode(policy))
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则失败！err:", err)
    end
    return ok, err
end

-- 删除指定路由规则
-- @param hostkey：路由key
function _M:delRouterPolicy(hostkey)
    local cacheKey = ROUTER_PREFIX .. hostkey
    local ok, err = self.db:del(cacheKey)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]删除路由规则失败！err:", err)
    end
    return ok, err
end

-- 全量查询路由规则
-- @param cursor：指针
-- @param match：匹配规则
-- @param count：查询数量
function _M:getAllRouterPolicy(cursor, count)
    local res, err = self.db:scan(cursor, "MATCH", MATCH, "COUNT", count)
    local result
    if res then
        result = {
            cursor = res[1],
            data = {}
        }
        -- 增加pipeline支持
        local keys = res[2]
        self.db:init_pipeline(#keys)
        for _, k in ipairs(keys) do
            self.db:get(k)
        end
        local results, err = self.db:commit_pipeline()

        if not results then
            LOGGER(ERR, "failed to commit the pipelined requests: ", err)
            return
        else
            for i, k in ipairs(keys) do
                local res = results[i]
                if type(res) == "table" and res[1] == false then
                    result.data[k:sub(#ROUTER_PREFIX + 1)] = { error = true, message = res[2] }
                else
                    result.data[k:sub(#ROUTER_PREFIX + 1)] = cjson.decode(res)
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
    if db then
        return setmetatable({ db = db }, { __index = _M })
    end
    error("redis实例不能为nil,可能是PHI还未初始化？")
end

return class