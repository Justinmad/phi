--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 17:35
-- 查询db和shared缓存
--
local cjson = require "cjson"
local CONST = require "core.constants"
local mlcache = require "resty.mlcache"

local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE

local SHARED_DICT_NAME = CONST.DICTS.PHI_ROUTER
local PHI_EVENTS_DICT_NAME = CONST.DICTS.PHI_EVENTS

local LOCK_NAME = CONST.DICTS.PHI_LOCK
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local class = {}
local _M = {}

-- 初始化worker
function _M:init_worker(observer)
    self.observer = observer
end

-- 获取单个路由规则
function _M:getRouterPolicy(hostkey)
    self.cache:get(hostkey, function()
        local res, err self.dao.getRouterPolicy(hostkey)
        if err then
            -- 查询出现错误，10秒内不再查询
            LOGGER(ERR, "could not retrieve router policy:", err)
            return { skipRouter = true }, nil, 10
        end
        return res or { skipRouter = true }
    end)
end

-- 新增or更新路由规则
function _M:setRouterPolicy(hostkey, policyStr)

end

-- 删除路由规则
function _M:delRouterPolicy(hostkey)

end

-- 分页查询
function _M:getAllRouterPolicy(from, count)

end

function class:new(ref, config)
    local cache,err =  mlcache.new("router_cache", SHARED_DICT_NAME, {
        lru_size = config.router_lrucache_size or 1000,     -- size of the L1 (Lua-land LRU) cache
        ttl      = 0,                                       -- 缓存失效时间
        neg_ttl  = 0,                                       -- 未命中缓存失效时间
        resty_lock_opts = Lock:new(LOCK_NAME),
        ipc_shm = PHI_EVENTS_DICT_NAME
    })
    if err then
        error("could not create mlcache for router cache ! err :" .. err)
    end
    return setmetatable({ dao = ref, cache = cache }, { __index = _M })
end

return class