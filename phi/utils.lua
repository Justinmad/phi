--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 17:32
-- 封装一些常用的方法
--
local ngx = ngx
local utils = {}
-- 判断文件是否存在
-- 所有io操作都应谨慎使用，在openresty中非官方库的io操作很可能会阻塞整个worker进程
function utils.file_exists(path)

    local status, file = pcall(io.open, path, "rb")
    if status then
        if file then file:close() end
    end

    return file ~= nil
end

-- 获取请求头中Host的值，使用此字段作为默认情况下的路由key
-- 特殊情况下可以设置ngx.var.hostkey的值作为路由key
-- 同一请求，直接将结果放入ngx.ctx，避免多次调用ngx.var，这个api性能开销很大
-- @see https://github.com/openresty/lua-nginx-module#ngxvarvariable
function utils.getHost(ctx)
    local result = ctx.__host;
    if not result then
        -- 获取到请求头中的Host
        result = ngx.req.get_headers()['Host']
        if result then
            -- 获取到变量中的HostKey，则优先使用
            local hostkey = ngx.var.hostkey
            if hostkey then
                result = hostkey
            end
            ctx.__host = result;
        end
    end

    return result
end

local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end
local getn = table.getn
local insert = table.insert
local concat = table.concat

local SHARED_DICT = ngx.shared
function utils.printDict(dictName)
    local dict = SHARED_DICT[dictName]
    local keys = dict:get_keys()
    local t = new_tab(0, getn(keys))
    for _, k in ipairs(keys) do
        insert(t, k .. " = ".. dict:get(k))
    end
    print(concat(t, "\r\n"))
end

return utils