--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 17:32
-- 封装一些常用的方法
--
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
function utils.getHost()
    local result = ngx.ctx._host;

    if not result then
        -- 获取到请求头中的Host
        result = ngx.req.get_headers()['Host']
        if result then
            -- 获取到变量中的HostKey，则优先使用
            local hostkey = ngx.var.hostkey
            if hostkey then
                result = hostkey
            end
            ngx.ctx._host = result;
        end
    end

    return result
end

function getHeader(header)
    local field = "_cache_" .. header
    local result = ngx.ctx[field];

    if not result then
        -- 获取到请求头中的Host
        result = ngx.req.get_headers()[header]
        if result then
            ngx.ctx[field] = result;
        end
    end

    return result
end

return utils