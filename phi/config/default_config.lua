--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:33
-- 系统默认配置
--
local split = require "pl.stringx".split
local concat = table.concat
local remove = table.remove

local current_file = debug.getinfo(1, 'S').source
current_file = current_file:sub(2)
current_file = current_file:gsub("\\", "/")
local tmp = split(current_file, "/")
remove(tmp, #tmp)

local current_path = concat(tmp, "/") .. "/"
local conf_path = current_path .. "../../conf/"
local bin_path = current_path .. "../../bin/"

return {
    debug = false,
    debug_host = "127.0.0.1",
    debug_port = 8172,
    redis_host = "127.0.0.1",
    redis_port = 6379,
    redis_db_index = 1,
    redis_pool_size = 100,
    redis_keepalive = 10000,
    enabled_admin = true,
    enabled_mio = false,
    -- enabled_policies = { "unique", "range", "prefix", "suffix", "composite", "modulo", "regex" },
    enabled_policies = { "unique", "range", "prefix", "suffix", "modulo", "regex" },
    enabled_mappers = { "header", "uri_args", "ip", "uri" },
    enabled_components = { "jwt" },
    default_paths = {
        current_path .. "phi.ini", conf_path .. "phi.ini", bin_path .. "phi.ini"
    },
    application_context_conf = {
        current_path .. "application.ini", conf_path .. "application.ini", bin_path .. "application.ini"
    }
}