--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/12
-- Time: 15:39
-- redis连接工具类.
-- 使用方式：
-- copy from https://github.com/anjia0532/lua-resty-redis-util
-- copy from https://moonbingbing.gitbooks.io/openresty-best-practices/content/redis/out_package.html
--
local redis_c = require("resty.redis")
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local WARN = ngx.WARN
local LOGGER = ngx.log
local pairs = pairs
local null = ngx.null
local type = type
local rawget = rawget
local ipairs = ipairs
local unpack = unpack
local remove = table.remove

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function(narr, nrec) return {} end
end

local class = new_tab(0, 1)

local _M = new_tab(0, 60)
local function log(msg, err)
    LOGGER(ERR, msg, err)
end

-- if res is ngx.null or nil or type(res) is table and all value is ngx.null return true else false
local function _is_null(res)
    if type(res) == "table" then
        for _, v in pairs(res) do
            if v ~= null then
                return false
            end
        end
    elseif res == null or res == nil then
        return true
    end

    return false
end

-- 建立连接
local function _do_connect(config, redis)
    -- 连接
    local ok, err = redis:connect(config.redis_host, config.redis_port)
    if not ok or err then
        log("连接初始化失败,err:", err)
        return nil, err
    end

    -- 认证
    local times, err = redis:get_reused_times()
    if times == 0 then
        if config.redis_password then
            local ok, err = redis:auth(config.redis_password)
            if not ok or err then
                log("redis auth认证失败,err:", err)
                return nil, err
            end
        end
        if config.redis_db_index > 0 then
            local ok, err = redis:select(config.redis_db_index)
            if not ok or err then
                log("选择redis db_index:" .. config.redis_db_index .. "failed ,err:", err)
                return nil, err
            end
        end
    elseif err then
        log("获取连接使用次数失败,err:", err)
        return nil, err
    end
    return redis, nil
end

-- 创建Redis对象
local function _init_connect(config)
    -- init redis
    local redis, err = redis_c:new()
    if not redis then
        log("创建redis实例失败,err:", err)
        return nil, err
    end
    -- get connect
    local ok, err = _do_connect(config, redis)
    if not ok or err then
        log("建立redis连接失败,err:", err)
        return nil, err
    end
    return redis, nil
end

local function _set_keepalive(config, redis)
    return redis:set_keepalive(config.redis_keepalive, config.redis_pool_size)
end

-- 发送Redis指令
local function do_command(self, cmd, ...)
    -- pipeline reqs
    local _reqs = rawget(self, "_reqs")
    if _reqs then
        -- append reqs
        _reqs[#_reqs + 1] = { cmd, ... }
        return
    end
    -- 初始化连接
    local red, err = _init_connect(self.conf)
    if err then return nil, err end

    -- 执行redis指令
    local method = red[cmd]
    local result, err = method(red, ...)
    if not result or err then
        return nil, err
    end

    -- check null
    if _is_null(result) then
        result = nil
    end

    -- 返回连接池
    local ok, err = _set_keepalive(self.conf, red)
    if not ok or err then
        return nil, err
    end

    return result, nil
end

-- init pipeline,default cmds num is 4
function _M:init_pipeline(n)
    self._reqs = new_tab(n or 4, 0)
end

-- cancel pipeline
function _M:cancel_pipeline()
    self._reqs = nil
end

-- commit pipeline
function _M:commit_pipeline()
    -- get cache cmds
    local _reqs = rawget(self, "_reqs")
    if not _reqs then
        LOGGER(ERR, "failed to commit pipeline,reason:no pipeline")
        return nil, "no pipeline"
    end
    self._reqs = nil

    -- init redis
    local redis, err = _init_connect(self.conf)
    if not redis then
        LOGGER(ERR, "failed to init redis,reason:", err)
        return nil, err
    end

    redis:init_pipeline()

    --redis command like set/get ...
    for _, vals in ipairs(_reqs) do
        -- vals[1] is redis cmd
        local fun = redis[vals[1]]
        -- get params without cmd
        remove(vals, 1)
        -- invoke redis cmd
        fun(redis, unpack(vals))
    end
    -- commit pipeline
    local results, err = redis:commit_pipeline()
    if not results or err then
        LOGGER(ERR, "failed to commit pipeline,reason:", err)
        return {}, err
    end

    -- check null
    if _is_null(results) then
        results = {}
        LOGGER(WARN, "redis result is null")
    end

    -- put it into the connection pool
    _set_keepalive(self.conf, redis)

    -- if null set default value nil
    for i, value in ipairs(results) do
        if _is_null(value) then
            results[i] = nil
        end
    end
    return results, err
end

-- subscribe
function _M:subscribe(channel)

    -- init redis
    local redis, err = _init_connect(self.conf)
    if not redis then
        LOGGER(ERR, "failed to init redis,reason::", err)
        return nil, err
    end

    -- sub channel
    local res, err = redis:subscribe(channel)
    if not res then
        LOGGER(ERR, "failed to subscribe channel,reason:", err)
        return nil, err
    end

    local function do_read_func(do_read)
        if do_read == nil or do_read == true then
            res, err = redis:read_reply()
            if not res then
                LOGGER(ERR, "failed to read subscribe channel reply,reason:", err)
                return nil, err
            end
            return res
        end

        -- if do_read is false
        redis:unsubscribe(channel)
        _set_keepalive(self.conf, redis)
        return
    end

    return do_read_func
end

setmetatable(_M, {
    __index = function(self, cmd)
        if cmd == "init" or cmd == "new" or cmd == "init_worker" then
            return
        end
        local method = function(self, ...)
            return do_command(self, cmd, ...)
        end
        self[cmd] = method
        return method
    end
})

-- 根据配置生成
function class:new(config)
    -- 初始化Redis
    local instance = new_tab(0, 60)
    instance.conf = {}
    LOGGER(DEBUG, "********************初始化Redis********************")
    instance.conf.redis_host = config.redis_host or "127.0.0.1"
    instance.conf.redis_port = config.redis_port or 6379
    instance.conf.timeout = config.timeout or 1000
    instance.conf.redis_db_index = config.redis_db_index or 0
    instance.conf.redis_password = config.redis_password or nil
    instance.conf.redis_keepalive = config.redis_keepalive or 10000
    instance.conf.redis_pool_size = config.redis_pool_size or 100
    LOGGER(DEBUG, "初始化Redis成功！host:[" .. instance.conf.redis_host .. "],port:[" .. instance.conf.redis_port .. "]")
    LOGGER(DEBUG, "==================初始化Redis结束==================")
    return setmetatable(instance, { __index = _M })
end

return class