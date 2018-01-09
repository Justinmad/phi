return {
    HEADERS = {
        HOST_OVERRIDE = "X-Host-Override",
        PROXY_LATENCY = "X-Kong-Proxy-Latency",
        UPSTREAM_LATENCY = "X-Kong-Upstream-Latency",
        CONSUMER_ID = "X-Consumer-ID",
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
    DICTS = {
        "phi",
        "phi_cache"
    }
}
