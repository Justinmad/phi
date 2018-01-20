--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/12
-- Time: 15:39
-- redis连接工具类.
-- 使用方式：
-- local redis = require "tools.redis"
-- local red = redis:new(config)
-- red.set("a key","value")
--
local redis_c = require("resty.redis")
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local LOGGER = ngx.log

local _M = {
    conf = {}
}

local mt = { __index = _M }

local function log(msg, err)
    LOGGER(ERR, msg, err)
end

-- if res is ngx.null or nil or type(res) is table and all value is ngx.null return true else false
local function _is_null(res)
    if type(res) == "table" then
        for _, v in pairs(res) do
            if v ~= ngx.null then
                return false
            end
        end
    elseif res == ngx.null or res == nil then
        return true
    end

    return false
end

-- 建立连接
local function _connect_mod(config, redis)
    -- 连接
    local ok, err = redis:connect(config.redis_host, config.redis_port)
    if not ok or err then
        log("连接初始化失败,err:", err)
        return nil, err
    end

    -- 认证
    if config.redis_password then
        local times, err = redis:get_reused_times()
        if times == 0 then
            local ok, err = redis:auth(config.redis_password)
            if not ok or err then
                log("redis auth认证失败,err:", err)
                return nil, err
            end
        elseif err then
            log("获取连接使用次数失败,err:", err)
            return nil, err
        end
    end

    -- 选择Redis db
    if config.redis_db_index > 0 then
        local ok, err = redis:select(config.redis_db_index)
        if not ok or err then
            log("选择redis db_index:" .. config.redis_db_index .. "failed ,err:", err)
            return nil, err
        end
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
    local ok, err = _connect_mod(config, redis)
    if not ok or err then
        log("建立redis连接失败,err:", err)
        return nil, err
    end
    return redis, nil
end

local function _set_keepalive(config, redis)
    return redis:set_keepalive(config.redis_keepalive, config.redis_pool_size)
end

-- 发送Redis指令，不支持pipeline，subscribe
local function do_command(self, config, cmd, ...)
    -- 初始化连接
    local red, err = _init_connect(config)
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
    local ok, err = _set_keepalive(config, red)
    if not ok or err then
        return nil, err
    end

    return result, nil
end

-- 根据配置生成
function _M:new(config)
    self.conf.redis_host = config.redis_host
    self.conf.redis_port = config.redis_port
    self.conf.redis_db_index = config.redis_db_index
    self.conf.redis_password = config.redis_password
    self.conf.redis_keepalive = config.redis_keepalive
    self.conf.redis_pool_size = config.redis_pool_size
    LOGGER(DEBUG, "初始化Redis成功！host:[" .. self.conf.redis_host .. "],port:[" .. self.conf.redis_port .. "]")
    return setmetatable({}, mt)
end

setmetatable(_M, {
    __index = function(self, cmd)
        local instance = self;
        local method = function(self, ...)
            return do_command(self, instance.conf, cmd, ...)
        end

        -- cache the lazily generated method in our
        -- module table
        _M[cmd] = method
        return method
    end
})
return _M