-- -*- coding: utf-8 -*-

local common = require "gateway.module.common"
local upstream = require "ngx.upstream"

local _M = {}

local STATUS_INIT = "status_init"

local TOTAL_COUNT = "total_count"
local TOTAL_COUNT_SUCCESS = "total_success_count"
local CURRENT_QPS = "current_qps"
local TIMEOUT_QPS = 60 * 10

local TRAFFIC_READ = "traffic_read"
local TRAFFIC_WRITE = "traffic_write"

local NGX_LOAD_TIMESTAMP = 'ngx_load_time'
local NGX_RELOAD_GENERATION = 'ngx_reload_generation'

local TIME_TOTAL = "time_total"
local MASTER_PID = "master_pid"

local SERVER_ZONES = "server_zones"
local PROCESSING = 'processing'
local RECEIVED = 'received'
local DISCARDED = 'discarded'
local SENT = 'sent'
local RESPONSE = 'response'
local RESPONSE_CODE = "response_code"

local UPSTREAM_TIME_SUM = 'upstream_time_sum'
local UPSTREAM_REQUEST_COUNT = 'upstream_request_count'

local UPSTREAM_CNT = "upstream_cnt"
local UPSTREAM_REQUEST_LEN = "upstream_request_len"
local UPSTREAM_REP_LEN = "upstream_rep_len"
local UPSTREAM_REP_TIME = "upstream_rep_time"

local shared_status = ngx.shared.status

-- maybe optimized, read from redis
function _M.init()
    local newval, err = shared_status:incr(NGX_RELOAD_GENERATION, 1)
    if not newval and err == "not found" then
        shared_status:add(NGX_RELOAD_GENERATION, 0)
    end

    shared_status:set( NGX_LOAD_TIMESTAMP, ngx.time()) -- set nginx reload/restart begin uptime

    local ok, err = shared_status:add( STATUS_INIT, true )
    if ok then
        --if nginx from stop to start
        shared_status:set( TOTAL_COUNT, 0 )
        shared_status:set( TOTAL_COUNT_SUCCESS, 0 )

        shared_status:set( TRAFFIC_READ, 0 )
        shared_status:set( TRAFFIC_WRITE, 0 )

        shared_status:set( TIME_TOTAL, 0 )
        shared_status:set( MASTER_PID, ngx.worker.pid() )
    end

end

local function hook_for_upstream()
    local cur_seconds = ngx.time()
    local upstream_name = ngx.var.proxy_host
    local addr = ngx.var.upstream_addr -- TODO：看文档这个会有多个值，后面需要精准获取一个，还不知道怎么获取
    if upstream_name and addr then
        local upstream_key = upstream_name .. '_' .. addr

        if ngx.var.upstream_status then
            -- upstreams 可能挂了，返回的 code 是 nil
            local status = math.floor((tonumber(ngx.var.upstream_status) or 500) / 100) .. 'xx'
            local newval, err = shared_status:incr(upstream_key .. RESPONSE_CODE .. status, 1)
            if not newval and err == "not found" then
                shared_status:set(upstream_key .. RESPONSE_CODE .. status, 1)
            end
        end

        --UPSTREAM_REQUEST_LEN
        local newval, err = shared_status:incr(upstream_key .. UPSTREAM_REQUEST_LEN, tonumber(ngx.var.request_length) or 0)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. UPSTREAM_REQUEST_LEN, tonumber(ngx.var.request_length))
        end

        -- send_per_second
        local newval, err = shared_status:incr(upstream_key .. UPSTREAM_REQUEST_LEN .. cur_seconds, tonumber(ngx.var.request_length) or 0)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. UPSTREAM_REQUEST_LEN .. cur_seconds, tonumber(ngx.var.request_length), TIMEOUT_QPS)
        end

        -- UPSTREAM_REP_LEN
        local newval, err = shared_status:incr(upstream_key .. UPSTREAM_REP_LEN, tonumber(ngx.var.upstream_response_length) or 0)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. UPSTREAM_REP_LEN, tonumber(ngx.var.upstream_response_length))
        end

        -- receive_per_second
        local newval, err = shared_status:incr(upstream_key .. UPSTREAM_REP_LEN .. cur_seconds, tonumber(ngx.var.upstream_response_length) or 0)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. UPSTREAM_REP_LEN .. cur_seconds, tonumber(ngx.var.upstream_response_length) or 0, TIMEOUT_QPS)
        end

        -- qps
        local newval, err = shared_status:incr(upstream_key .. CURRENT_QPS .. cur_seconds, 1)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. CURRENT_QPS .. cur_seconds, 1, TIMEOUT_QPS)
        end

        -- UPSTREAM_TIME_SUM
        local upstream_time = tonumber(ngx.var.upstream_response_time) or 0
        local sum = shared_status:get(upstream_key .. UPSTREAM_TIME_SUM) or 0
        shared_status:set(upstream_key .. UPSTREAM_TIME_SUM, sum + upstream_time)

        -- UPSTREAM_REQUEST_COUNT
        local newval, err = shared_status:incr(upstream_key .. UPSTREAM_REQUEST_COUNT, 1)
        if not newval and err == "not found" then
            shared_status:set(upstream_key .. UPSTREAM_REQUEST_COUNT, 1)
        end
    end
end

local function hook_for_server()
    local server_zone = ngx.var.server_name
    if not server_zone or server_zone == '' then
        return
    end

    local server_key = SERVER_ZONES .. '_' .. server_zone
    local cur_seconds = ngx.time()

    -- request qps
    local newval, err = shared_status:incr(server_key .. CURRENT_QPS .. cur_seconds, 1)
    if not newval and err == "not found" then
        shared_status:set(server_key .. CURRENT_QPS .. cur_seconds, 1, TIMEOUT_QPS)
    end

    -- requests total
    local newval, err = shared_status:incr(server_key, 1)
    if not newval and err == "not found" then
        shared_status:set(server_key, 1)
        -- 因为现在还没有获取所有 Server zone 的方法，所以这里把有用户请求的 server zone 单独存起来
        local server_zones = shared_status:get(SERVER_ZONES)
        if server_zones then
            server_zones = common.json_decode(server_zones)
            table.insert(server_zones, server_zone)
        else
            server_zones = { server_zone }
        end
        shared_status:set(SERVER_ZONES, common.json_encode(server_zones))
    end

    -- response code stat
    if ngx.var.status then
        -- 请求可能被丢弃，返回的 code 是 nil
        -- stat all response
        local newval, err = shared_status:incr(server_key .. RESPONSE, 1)
        if not newval and err == "not found" then
            shared_status:set(server_key .. RESPONSE, 1)
        end
        -- stat response code
        local status = math.floor(tonumber(ngx.var.status) / 100) .. 'xx'
        local newval, err = shared_status:incr(server_key .. RESPONSE_CODE .. status, 1)
        if not newval and err == "not found" then
            shared_status:set(server_key .. RESPONSE_CODE .. status, 1)
        end
    else
        -- 请求被丢弃
        local newval, err = shared_status:incr(server_key .. DISCARDED, 1)
        if not newval and err == "not found" then
            shared_status:set(server_key .. DISCARDED, 1)
        end
    end

    -- received_length sum
    local received_length = tonumber(ngx.var.request_length)
    local sum = shared_status:get(server_key .. RECEIVED) or 0
    shared_status:set(server_key .. RECEIVED, sum + received_length)

    -- receive per second
    local newval, err = shared_status:incr(server_key .. RECEIVED .. cur_seconds, received_length)
    if not newval and err == "not found" then
        shared_status:set(server_key .. RECEIVED .. cur_seconds, received_length, TIMEOUT_QPS)
    end

    -- sent_length sum
    local sent_length = tonumber(ngx.var.bytes_sent)
    local sum = shared_status:get(server_key .. SENT) or 0
    shared_status:set(server_key .. SENT, sum + sent_length)

    -- send per second
    local newval, err = shared_status:incr(server_key .. SENT .. cur_seconds, sent_length)
    if not newval and err == "not found" then
        shared_status:set(server_key .. SENT .. cur_seconds, sent_length, TIMEOUT_QPS)
    end
end

--add global count info
function _M.log()
    local host = ngx.var.host
    local up_addr = ngx.var.upstream_addr
    local seconds = ngx.time()
    -- requests
    shared_status:incr( TOTAL_COUNT, 1 )

    if tonumber(ngx.var.status) < 400 then
        shared_status:incr( TOTAL_COUNT_SUCCESS, 1 )
    end

    local newval, err = shared_status:incr(CURRENT_QPS .. seconds, 1)
    if not newval and err == "not found" then
        shared_status:set(CURRENT_QPS .. seconds, 1)
    end

    local newval, err = shared_status:incr(TRAFFIC_READ, tonumber(ngx.var.request_length))
    if not newval and err == "not found" then
        shared_status:set(TRAFFIC_READ, tonumber(ngx.var.request_length))
    end

    local newval, err = shared_status:incr(TRAFFIC_WRITE, tonumber(ngx.var.bytes_sent))
    if not newval and err == "not found" then
        shared_status:set(TRAFFIC_WRITE, tonumber(ngx.var.bytes_sent))
    end

    shared_status:incr(TIME_TOTAL, ngx.var.request_time)

    -- upstream
    hook_for_upstream()

    -- server zone
    hook_for_server()
end

local function get_nginx_info()
    local dict_status = ngx.shared.status
    local ngx_lua_version = ngx.config.ngx_lua_version --例如 0.9.2 就对应返回值 9002; 1.4.3 就对应返回值 1004003

    local report = {}
    report.nginx_version = ngx.var.nginx_version
    report.ngx_lua_version = math.floor(ngx_lua_version / 1000000) .. '.' .. math.floor(ngx_lua_version / 1000) .. '.' .. math.floor(ngx_lua_version % 1000)
    report.address = ngx.var.server_addr .. ":" .. ngx.var.server_port
    report.worker_count = ngx.worker.count()
    report.load_timestamp = dict_status:get(NGX_LOAD_TIMESTAMP)
    report.timestamp = ngx.time()
    report.generation = dict_status:get(NGX_RELOAD_GENERATION)
    report.pid = dict_status:get( MASTER_PID )
    return report
end

local function get_connections_info()
    local report = {}
    report.current = tonumber(ngx.var.connections_active) --包括读、写和空闲连接数
    report.active = ngx.var.connections_reading + ngx.var.connections_writing
    report.idle = tonumber(ngx.var.connections_waiting)
    report.writing = tonumber(ngx.var.connections_writing)
    report.reading = tonumber(ngx.var.connections_reading)

    return report
end

local function get_requests_info()
    local cur_seconds = ngx.time() - 1

    local report = {}
    report.total = ngx.shared.status:get(TOTAL_COUNT)
    report.success = ngx.shared.status:get(TOTAL_COUNT_SUCCESS)
    report.current = ngx.shared.status:get(CURRENT_QPS .. cur_seconds) or 0

    return report
end

function get_upstream_peers_info(upstream_name, peers_info)
    local upstream_key = upstream_name .. '_' .. peers_info.name
    local last_seconds = ngx.time() - 1

    local upstream_stat = {}
    upstream_stat.id = peers_info.id
    upstream_stat.server = peers_info.name
    upstream_stat.down = peers_info.down
    upstream_stat.backup = peers_info.backup
    upstream_stat.weight = peers_info.weight
    upstream_stat.fails = peers_info.fails
    upstream_stat.active = peers_info.conns or 0 --this requires NGINX 1.9.0 or above
    upstream_stat.requests = shared_status:get(upstream_key .. UPSTREAM_REQUEST_COUNT) or 0
    upstream_stat.sent = shared_status:get(upstream_key .. UPSTREAM_REQUEST_LEN) or 0
    upstream_stat.received = shared_status:get(upstream_key .. UPSTREAM_REP_LEN) or 0
    upstream_stat.send_per_second = shared_status:get(upstream_key .. UPSTREAM_REQUEST_LEN .. last_seconds) or 0
    upstream_stat.receive_per_second = shared_status:get(upstream_key .. UPSTREAM_REP_LEN .. last_seconds) or 0
    upstream_stat.qps = shared_status:get(upstream_key .. CURRENT_QPS .. last_seconds) or 0

    local response = {}
    local total = shared_status:get(upstream_key .. UPSTREAM_REQUEST_COUNT) or 0
    response.total = total
    for i = 1, 5 do
        response[i .. 'xx'] = shared_status:get(upstream_key .. RESPONSE_CODE .. i .. 'xx') or 0
    end
    upstream_stat.response = response

    local latency = { mean = 0, per_minute_mean = 0, per_minute_min = 0, per_minute_max = 0 }
    local time_sum = shared_status:get(upstream_key .. UPSTREAM_TIME_SUM)
    if time_sum and time_sum > 0 and total and total > 0 then
        latency.mean = time_sum / total * 1000 -- 单位是 ms
    end
    upstream_stat.latency = latency

    return upstream_stat
end

local function get_upstreams_info()
    local report = {}

    for _, upstream_name in ipairs(upstream.get_upstreams()) do
        report[upstream_name] = {}
        report[upstream_name].peers = {}
        for _, peers_info in ipairs(upstream.get_primary_peers(upstream_name)) do
            peers_info.backup = false
            table.insert(report[upstream_name].peers, get_upstream_peers_info(upstream_name, peers_info))
        end

        for _, peers_info in ipairs(upstream.get_backup_peers(upstream_name)) do
            peers_info.backup = true
            table.insert(report[upstream_name].peers, get_upstream_peers_info(upstream_name, peers_info))
        end
    end

    return report
end

local function get_server_zones()
    local report = {}
    local last_seconds = ngx.time() - 1

    local server_zones = shared_status:get(SERVER_ZONES)
    if server_zones then
        server_zones = common.json_decode(server_zones)
        for _, server_zone in ipairs(server_zones) do
            local server_info = {}
            local server_key = SERVER_ZONES .. '_' .. server_zone
            server_info.requests = shared_status:get(server_key) or 0
            server_info.discarded = shared_status:get(server_key .. DISCARDED) or 0
            server_info.received = shared_status:get(server_key .. RECEIVED) or 0
            server_info.receive_per_second = shared_status:get(server_key .. RECEIVED .. last_seconds) or 0
            server_info.sent = shared_status:get(server_key .. SENT) or 0
            server_info.send_per_second = shared_status:get(server_key .. SENT .. last_seconds) or 0

            local responses = {}
            responses.total = shared_status:get(server_key .. RESPONSE) or 0
            for i = 1, 5 do
                responses[i .. 'xx'] = shared_status:get(server_key .. RESPONSE_CODE .. i .. 'xx') or 0
            end
            server_info.responses = responses
            report[server_zone] = server_info
        end
    end
    return report
end

function _M.report()
    local report = {}
    report.version = 1 -- Version of the provided data set. The current version is 1

    report = get_nginx_info()
    report.connections = get_connections_info()
    report.requests = get_requests_info()
    report.upstreams = get_upstreams_info()
    report.server_zones = get_server_zones()
    ngx.log(ngx.DEBUG, common.json_encode(report))
    return report
end

return _M
