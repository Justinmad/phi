return {
    HEADERS = {
        HOST_OVERRIDE = "X-Host-Override",
        PROXY_LATENCY = "X-Kong-Proxy-Latency",
        UPSTREAM_LATENCY = "X-Kong-Upstream-Latency",
        CONSUMER_ID = "X-Phi-UID",
        CONSUMER_CUSTOM_ID = "X-Consumer-Custom-ID",
        CONSUMER_USERNAME = "X-Consumer-Username",
        CREDENTIAL_USERNAME = "X-Credential-Username",
        RATELIMIT_LIMIT = "X-RateLimit-Limit",
        RATELIMIT_REMAINING = "X-RateLimit-Remaining",
        CONSUMER_GROUPS = "X-Consumer-Groups",
        FORWARDED_HOST = "X-Forwarded-Host",
        FORWARDED_PREFIX = "X-Forwarded-Prefix",
        ANONYMOUS = "X-Anonymous-Consumer"
    },
    RATELIMIT = {
        PERIODS = {
            "second",
            "minute",
            "hour",
            "day",
            "month",
            "year"
        }
    },
    METHOD = {
        GET = "GET",                                            -- HTTP METHOD POST
        POST = "POST"                                           -- HTTP METHOD POST
    },
    DICTS = {
        PHI = "phi",                                            -- 没想好存什么，占位
        PHI_ROUTER = "phi_router",                              -- 存储路由信息，作为二级缓存
        PHI_LOCK = "phi_lock",                                  -- 存储锁信息
        PHI_EVENTS = "phi_events",                              -- 存储事件消息
        PHI_DYNAMIC_UPSTREAM = "phi_dynamic_upstream"           -- 存储动态配置的upstream信息和server信息
    },
    CACHE_KEY = {
        ROUTER = "PHI:CTRL:ROUTER:",                            -- 作为redis中路由规则的key
        RATE_LIMITING = "PHI:CTRL:RATE_LIMITING",               -- 作为redis中限流规则的key
        SERVICE_DEGRADATION = "PHI:CTRL:SERVICE_DEGRADATION",   -- 作为redis中降级规则的key
    },
    EVENT_DEFINITION = {
        ROUTER_SERVICE = {
            SOURCE = "router_service",
            DELETE = "delete",
            UPDATE = "update",
            CREATE = "create"
        }
    }
}
