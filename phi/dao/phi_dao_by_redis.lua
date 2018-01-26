--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/15
-- Time: 11:05
-- 主要负责从redis中加载数据
-- 必须要实现以下几个方法
-- getRouterPolicy(hostkey)
-- setRouterPolicy(routerKey, policy)
--
local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log
local cjson = require "cjson.safe"
local CONST = require "core.constants"
local ROUTER_PREFIX = CONST.CACHE_KEY.ROUTER

local class = {}

local _M = {}

function class:new(redis)
    if redis then
        return setmetatable({ db = redis }, { __index = _M }), nil
    end
    return nil, "redis实例不能为nil"
end

-- 根据主机名查询路由规则表
-- @parma routerKey：路由key
function _M:getRouterPolicy(hostkey)
    local policiesStr, err = self.db:get(hostkey)
    -- 查询db
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的路由规则")
    end
    return policiesStr, err
end

-- 添加指定路由规则到db
-- @parma routerKey：路由key
-- @parma policy：规则数据,json串
function _M:setRouterPolicy(routerKey, policy)
    local ok, err = self.db:set(routerKey, policy)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]保存路由规则失败！err:", err)
    end
    return ok, err
end

-- 删除指定路由规则
-- @parma routerKey：路由key
function _M:delRouterPolicy(routerKey)
    local ok, err = self.db:del(routerKey)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. routerKey .. "]删除路由规则失败！err:", err)
    end
    return ok, err
end

-- 全量查询路由规则
-- @param cursor：指针
-- @parma match：匹配规则
-- @parma count：查询数量
function _M:getAllRouterPolicy(cursor, match, count)
    local res, err = self.db:scan(cursor, "MATCH", match, "COUNT", count)
    if not res then
        LOGGER(ERR, "全量查询失败！err:", err)
    end

    local result = {
        cursor = res[1],
        data = {}
    }

    -- 增加pipeline支持
    local kes = res[2]
    self.db:init_pipeline(#kes)
    for _, k in ipairs(kes) do
        self.db:get(k)
    end
    local results, err = self.db:commit_pipeline()

    if not results then
        LOGGER(ERR, "failed to commit the pipelined requests: ", err)
        return
    else
        for i, k in ipairs(kes) do
            result.data[k:sub(#ROUTER_PREFIX + 1)] = cjson.decode(results[i])
        end
    end
    return result, err
end

return class