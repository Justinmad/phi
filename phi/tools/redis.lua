--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/12
-- Time: 15:39
-- redis连接工具类.
--
local redis_c = require("resty.redis")

local _M = {
    reids_host = '127.0.0.1',
    reids_port = 6379,
    reids_db_index = 0,
    reids_password = nil,
    reids_keepalive = 60000, --60s
    reids_pool_size = 100,
}

local mt = { __index = _M }

local function log(msg, err)
    ngx.log(ngx.ERROR, msg, err)
end

local function _connect_mod(self, redis)
    -- 连接
    local ok, err = redis:connect(self.reids_host, self.reids_port)
    if not ok or err then
        log("连接初始化失败,err:", err)
        return nil, err
    end

    -- 认证
    if slef.reids_password then
        local times, err = redis:get_reused_times()
        if times == 0 then
            local ok, err = redis:auth(self.reids_password)
            if not ok or err then
                log("redis auth认证失败,err:", err)
                return nil, err
            end
        elseif err then
            log("获取连接使用次数失败,err:", err)
            return nil, err
        end
    end

    -- 选择DB
    if db_index > 0 then
        local ok, err = redis:select(self.reids_db_index)
        if not ok or err then
            log("选择redis db_index:" .. self.reids_db_index .. "failed ,err:", err)
            return nil, err
        end
    end

    return redis, nil
end

local function _init_connect(self)
    -- init redis
    local redis, err = redis_c:new()
    if not redis then
        log("创建redis实例失败,err:", err)
        return nil, err
    end

    -- get connect
    local ok, err = _connect_mod(self, redis)
    if not ok or err then
        log("建立redis连接失败,err:", err)
        return nil, err
    end
    return redis, nil
end

local function _set_keepalive(self, redis)
    return redis:set_keepalive(self.reids_keepalive, self.reids_pool_size)
end

local function do_command(self, cmd, ...)
    -- 初始化连接
    local red, err = _init_connect(self)
    if err then return nil, err end

    -- 执行redis指令
    local method = red[cmd]
    local result, err = method(red, ...)
    if not result or err then
        return nil, err
    end

    -- 返回连接池
    local ok, err = _set_keepalive(self, red)
    if not ok or err then
        return nil, err
    end
end



-- 根据配置生成
function _M:new(config)
    self.reids_host = config.reids_host
    self.reids_port = config.reids_port
    self.reids_db_index = config.reids_db_index
    self.reids_password = config.reids_password
    self.reids_keepalive = config.reids_keepalive
    self.reids_pool_size = config.reids_pool_size
    return setmetatable(self, mt)
end

setmetatable(_M, {
    __index = function(self, cmd)
        local method = function(self, ...)
            return do_command(self, cmd, ...);
        end

        -- cache the lazily generated method in our
        -- module table
        _M[cmd] = method
        return method
    end
})
return _M