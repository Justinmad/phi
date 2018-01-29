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
    ADMIN = {
        URL_BASE = "/admin"
    },
    METHOD = {
        GET = "GET",
        POST = "POST"
    },
    DICTS = {
        PHI = "phi",
        PHI_ROUTER = "phi_router",
        PHI_LOCK = "phi_lock",
        PHI_EVENTS = "phi_events"
    },
    CACHE_KEY = {
        ROUTER = "PHI:CTRL:ROUTER:",
        RATE_LIMITING = "PHI:CTRL:RATE_LIMITING",
        SERVICE_DEGRADATION = "PHI:CTRL:SERVICE_DEGRADATION",
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
