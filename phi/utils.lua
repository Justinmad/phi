--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 17:32
-- 封装一些常用的方法
--
local ngx = ngx
local req_get_headers = ngx.req.get_headers
local getn = table.getn
local insert = table.insert
local concat = table.concat
local ipairs = ipairs
local print = print
local pcall = pcall
local require = require
local type = type
local io_open = io.open
local utils = {}
-- 判断文件是否存在
-- 所有io操作都应谨慎使用，在openresty中非官方库的io操作很可能会阻塞整个worker进程
function utils.file_exists(path)

    local status, file = pcall(io_open, path, "rb")
    if status then
        if file then file:close() end
    end

    return file ~= nil
end

-- 获取host，优先级ngx.var.hostkey->请求头中的host
function utils.getHost(ctx)
    local result = ctx.__host;
    if not result then
        local var = ngx.var
        result = var.hostkey or var.http_host or req_get_headers()['Host']
        ctx.__host = result
    end
    return result
end

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end

local SHARED_DICT = ngx.shared
function utils.printDict(dictName)
    local dict = SHARED_DICT[dictName]
    local keys = dict:get_keys()
    local t = new_tab(0, getn(keys))
    for _, k in ipairs(keys) do
        insert(t, k .. " = " .. dict:get(k))
    end
    print(concat(t, "\r\n"))
end

return utils