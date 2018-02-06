--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:33
-- 系统默认配置
--
return {
    db_update_frequency = 5,
    db_update_propagation = 0,
    db_cache_ttl = 3600,
    lua_socket_pool_size = 30,
    enabled_policies = { "RANGE", "SUFFIX", "COMPOSITE", "MODULO" },
    enabled_mappers = { "HEADER", "URI_ARGS", "IP", "URI" },
    default_paths = {
        "E:/work/phi/conf/phi.ini", "/home/young/IdeaProjects/phi/conf/phi.ini"
    },
    router_lrucache_size = 2e3,
    upstream_lrucache_size = 2e3,
    enabled_admin = true,
    application_context_conf = { "E:/work/phi/phi/config/application.ini", "/home/young/IdeaProjects/phi/phi/config/application.ini" }
}