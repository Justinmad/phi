--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/23
-- Time: 17:35
-- 查询db和多级缓存
-- L1:Worker级别的LRU CACHE
-- L2:共享内存SHARED_DICT
-- L3:Redis,作为回源DB使用
--
local CONST = require "core.constants"
local mlcache = require "resty.mlcache"
local pretty_write = require("pl.pretty").write
local worker_pid = ngx.worker.pid

local EVENTS = CONST.EVENT_DEFINITION.ROUTER_SERVICE
local UPDATE = EVENTS.UPDATE

local SHARED_DICT_NAME = CONST.DICTS.PHI_ROUTER
local PHI_EVENTS_DICT_NAME = CONST.DICTS.PHI_EVENTS

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log

local _M = {}

local function sortSerializer(row)
    if not row.skipRouter then
        -- 排序
        table.sort(row.policies, function(r1, r2) return r1.order < r2.order end)
    end
    return row
end

-- 初始化worker
function _M:init_worker(observer)
    self.observer = observer

    -- 注册关注事件handler到指定事件源
    observer.register(function(data, event, source, pid)
        if worker_pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            if event == EVENTS.DELETE then
                self.cache:set({ skipRouter = true })
            elseif event == EVENTS.UPDATE or event == EVENTS.CREATE then
                -- 更新缓存
                self.cache:update()
            end
            LOGGER(DEBUG, "received event; source=", source,
                ", event=", event,
                ", data=", pretty_write(data),
                ", from process ", pid)
        end
    end, EVENTS.SOURCE)
end

function _M:updateEvent(hostkey)
    self.observer.post(EVENTS.SOURCE, UPDATE, hostkey)
end

-- 获取单个路由规则
function _M:getRouterPolicy(hostkey)
    local result, err = self.cache:get(hostkey, nil, function()
        local res, err = self.dao:getRouterPolicy(hostkey)
        if err then
            -- 查询出现错误，10秒内不再查询
            LOGGER(ERR, "could not retrieve router policy:", err)
            return { skipRouter = true }, nil, 10
        end
        return res or { skipRouter = true }
    end)
    return result, err
end

-- 新增or更新路由规则
function _M:setRouterPolicy(hostkey, policies)
    local ok, err = self.dao:setRouterPolicy(hostkey, policies)
    if ok then
        ok, err = self.cache:set(hostkey, nil, policies)
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]保存路由规则到shared_dict失败！err:", err)
        else
            self:updateEvent(hostkey)
        end
    end
    return ok, err
end

-- 删除路由规则
function _M:delRouterPolicy(hostkey)
    local ok, err = self.dao:delRouterPolicy(hostkey)
    if ok then
        ok, err = self.cache:set(hostkey, nil, { skipRouter = true })
        if not ok then
            LOGGER(ERR, "通过hostkey：[" .. hostkey .. "]从shared_dict删除路由规则失败！err:", err)
        else
            self:updateEvent(hostkey)
        end
    end
    return ok, err
end

-- 分页查询
function _M:getAllRouterPolicy(from, count)
    local ok, err = self.dao:getAllRouterPolicy(from, count)
    if err then
        LOGGER(ERR, "全量查询路由规则失败！err:", err)
    end
    return ok, err
end

local class = {}

function class:new(ref, config)
    -- new函数我会在init阶段调用，我在这里就初始化cache，并且在init函数中load部分数据，worker进程会fork这部分内存，相当于缓存的预热
    local cache, err = mlcache.new("router_cache", SHARED_DICT_NAME, {
        lru_size = config.router_lrucache_size or 1000, -- L1缓存大小，默认取1000
        ttl = 0,                                        -- 缓存失效时间
        neg_ttl = 0,                                    -- 未命中缓存失效时间
        resty_lock_opts = {                             -- 回源DB的锁配置
            exptime = 10,                               -- 锁失效时间
            timeout = 5                                 -- 获取锁超时时间
        },
        ipc_shm = PHI_EVENTS_DICT_NAME,                 -- 通知其他worker的事件总线
        l1_serializer = sortSerializer                  -- 结果排序处理
    })
    if err then
        error("could not create mlcache for router cache ! err :" .. err)
    end
    return setmetatable({ dao = ref, cache = cache }, { __index = _M })
end

return class