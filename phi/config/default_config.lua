--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:33
-- 系统默认配置
--
return {
    database = redis,
    -----------------------
    -- 以下是redis的默认配置
    -----------------------
    redis_host = "127.0.0.1",
    redis_port = 6379,
    redis_db_index = 0,
    redis_auth = false,
    redis_password = NONE,
    redis_pool_size = 60,
    redis_keepalive = 2000,

    db_update_frequency = 5,
    db_update_propagation = 0,
    db_cache_ttl = 3600,
    lua_socket_pool_size = 30
}