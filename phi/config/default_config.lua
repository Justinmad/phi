--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:33
-- 系统默认配置
--
local current_path = debug.getinfo(1, 'S').short_src .. "/../"

local conf_path = current_path .. "../../conf/"

return {
    enabled_admin = true,
    enabled_policies = { "RANGE", "SUFFIX", "COMPOSITE", "MODULO", "REGEX" },
    enabled_mappers = { "HEADER", "URI_ARGS", "IP", "URI" },
    default_paths = {
        current_path .. "phi.ini", conf_path .. "phi.ini"
    },
    application_context_conf = {
        current_path .. "application.ini", conf_path .. "application.ini"
    }
}