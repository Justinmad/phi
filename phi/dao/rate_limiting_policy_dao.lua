--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 16:38
-- 数据存储层，动态的限流规则
--
local CONST = require "core.constants"
local cjson = require "cjson.safe"

local ALERT = ngx.ALERT
local ERR = ngx.ERR
local LOGGER = ngx.log

local RATE_LIMITING_PREFIX = CONST.CACHE_KEY.RATE_LIMITING
local MATCH = RATE_LIMITING_PREFIX .. "*"
local _M = {}

function _M:getLimitPolicy(hostkey)
    local cacheKey = RATE_LIMITING_PREFIX .. hostkey
    local policiesStr, err = self.db:get(cacheKey)
    -- 查询db
    if err then
        LOGGER(ALERT, "通过hostkey：[" .. hostkey .. "]未查询到对应的限流规则！")
    end
    return cjson.decode(policiesStr), err
end

function _M:setLimitPolicy(hostkey, policy)
    local cacheKey = RATE_LIMITING_PREFIX .. hostkey
    local oldVal, err = self.db:getset(cacheKey, cjson.encode(policy))
    if err then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存限流规则失败！err:", err)
    end
    return cjson.decode(oldVal), err
end

function _M:delLimitPolicy(hostkey)
    local cacheKey = RATE_LIMITING_PREFIX .. hostkey
    local ok, err = self.db:del(cacheKey)
    if not ok then
        LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]删除限流规则失败！err:", err)
    end
    return ok, err
end

function _M:getAllLimitPolicy(cursor, count)
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
                    result.data[k:sub(#RATE_LIMITING_PREFIX + 1)] = { error = true, message = res[2] }
                else
                    result.data[k:sub(#RATE_LIMITING_PREFIX + 1)] = cjson.decode(res)
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