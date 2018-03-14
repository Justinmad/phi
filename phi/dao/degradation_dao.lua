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
local type = type

local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log

local SERVICE_DEGRADATION_PREFIX = CONST.CACHE_KEY.SERVICE_DEGRADATION
local MATCH = SERVICE_DEGRADATION_PREFIX .. "*"

local _M = {}

function _M:getDegradation(hostkey)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local policiesStr, err = self.db:get(cacheKey)
    -- 查询db
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的降级信息")
    end
    return cjson.decode(policiesStr), err
end

-- 添加指定路由规则到db
-- @param hostkey：路由key
-- @param policy：规则数据,json串
function _M:setDegradation(hostkey, policy)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local ok, err = self.db:set(cacheKey, cjson.encode(policy))
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存降级信息失败！err:", err)
    end
    return ok, err
end

-- 删除指定路由规则
-- @param hostkey：路由key
function _M:delDegradation(hostkey)
    local cacheKey = SERVICE_DEGRADATION_PREFIX .. hostkey
    local ok, err = self.db:del(cacheKey)
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
                    result.data[k:sub(#SERVICE_DEGRADATION_PREFIX + 1)] = { error = true, message = res[2] }
                else
                    result.data[k:sub(#SERVICE_DEGRADATION_PREFIX + 1)] = cjson.decode(res)
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