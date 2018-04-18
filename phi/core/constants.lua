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
        GET = "get",                                            -- HTTP METHOD GET
        POST = "post"                                           -- HTTP METHOD POST
    },
    DICTS = {
        PHI_ROUTER = "phi_router",                              -- 存储路由信息，作为二级缓存
        PHI_UPSTREAM = "phi_upstream",                          -- 存储upstream信息，作为二级缓存
        PHI_LIMITER = "phi_limiter",                            -- 存储limiter规则信息
        PHI_DEGRADER = "phi_degrader",                          -- 存储degrader规则信息
        PHI_LOCK = "phi_lock",                                  -- 存储锁信息
        PHI_EVENTS = "phi_events",                              -- 存储事件消息
        PHI_LIMIT_REQ = "phi_limit_req",                        -- 存储限流标记req
        PHI_LIMIT_CONN = "phi_limit_conn",                      -- 存储限流标记conn
        PHI_LIMIT_COUNT = "phi_limit_count"                     -- 存储限流标记count
    },
    CACHE_KEY = {
        UPSTREAM = "PHI:UPSTREAM:",                             -- 作为redis中upstream的key
        ROUTER = "PHI:CTRL:ROUTER:",                            -- 作为redis中路由规则的key
        RATE_LIMITING = "PHI:CTRL:RATE_LIMITING:",              -- 作为redis中限流规则的key
        SERVICE_DEGRADATION = "PHI:CTRL:SERVICE_DEGRADATION:"   -- 作为redis中降级规则的key
    },
    EVENT_DEFINITION = {
        ROUTER_EVENTS = {
            SOURCE = "router",
            UPDATE = "update"
        },
        UPSTREAM_EVENTS = {
            SOURCE = "peer",
            PEER_DOWN = "peer_down",
            PEER_UP = "peer_up",

            DYNAMIC_UPS_SOURCE = "dynamic_ups",
            DYNAMIC_UPS_DEL = "dynamic_ups_del",
            DYNAMIC_UPS_UPDATE = "dynamic_ups_update"
        },
        RATE_LIMITING_EVENTS = {
            SOURCE = "rate_limiting",
            UPDATE = "update",
            REBUILD = "rebuild",
        },
        SERVICE_DEGRADATION_EVENTS = {
            SOURCE = "service_degradation",
            UPDATE = "update"
        }
    }
}
