--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 16:21
-- 负责加载配置文件，处理默认的配置文件，或者进行配置覆盖
--
local pl_pretty = require "pl.pretty"
local pl_config = require "pl.config"
local utils = require "utils"
local tablex = require "pl.tablex"

local config_loader = {}
local _M = {}

local CONF_SENSITIVE = {
}

local CONF_SENSITIVE_PLACEHOLDER = "******"

local function overrides(k, default_v, file_conf, arg_conf)
    local value -- definitive value for this property

    -- default values have lowest priority
    if file_conf and file_conf[k] == nil then
        -- PL will ignore empty strings, so we need a placeholer (NONE)
        value = default_v == "NONE" and "" or default_v
    else
        -- given conf values have middle priority
        value = file_conf[k]
    end

    ------------------------
    -- 环境变量配置
    ------------------------
    local env_name = "PHI_" .. string.upper(k)
    local env = os.getenv(env_name)
    if env ~= nil then
        local to_print = env
        if CONF_SENSITIVE[k] then
            to_print = CONF_SENSITIVE_PLACEHOLDER
        end
        ngx.log(ngx.NOTICE, '%s ENV found with "%s"', env_name, to_print)
        value = env
    end

    -- arg_conf have highest priority
    if arg_conf and arg_conf[k] ~= nil then
        value = arg_conf[k]
    end

    return value, k
end

function _M.load()
    ------------------------
    -- 默认配置
    ------------------------

    local default_conf = require "config.default_config"

    if not default_conf then
        return nil, "could not load default conf: " .. err
    end

    ---------------------
    -- 配置文件
    ---------------------
    local from_file_conf, err, path
    -- try to look for a conf in default locations, but no big
    -- deal if none is found: we will use our defaults.
    local DEFAULT_PATHS = default_conf.default_paths

    for _, default_path in ipairs(DEFAULT_PATHS) do
        if utils.file_exists(default_path) then
            path = default_path
            break
        end
        ngx.log(ngx.NOTICE, "no config file found at ", default_path)
    end

    if not path or not utils.file_exists(path) then
        ngx.log(ngx.NOTICE, "no config file, skipping loading ")
    else
        local f = io.open(path, "r")
        if not f then
            return nil, err
        end

        ngx.log(ngx.NOTICE, "reading config file at ", path)

        from_file_conf, err = pl_config.read(f, {
            smart = false,
            list_delim = "_blank_" -- mandatory but we want to ignore it
        })
        f:close()
        if not from_file_conf then
            return nil, err
        end
    end

    local conf = tablex.pairmap(overrides, default_conf, (from_file_conf or {}), {})

    conf = tablex.merge(conf, default_conf) -- 取交集，删除多余的配置

    -- 打印最终配置在控制台
    do
        local conf_arr = {}
        for k, v in pairs(conf) do
            local to_print = v
            if CONF_SENSITIVE[k] then
                to_print = CONF_SENSITIVE_PLACEHOLDER
            end
            conf_arr[#conf_arr + 1] = k .. " = " .. pl_pretty.write(to_print, "")
        end

        table.sort(conf_arr)

        for i = 1, #conf_arr do
            ngx.log(ngx.NOTICE, conf_arr[i])
        end
    end

    return conf
end

setmetatable(config_loader, { __index = _M })

return config_loader