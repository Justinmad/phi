--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/22
-- Time: 10:48
-- To change this template use File | Settings | File Templates.
--
local ffi = require("ffi")

ffi.cdef [[
struct in_addr {
    uint32_t s_addr;
};

int inet_aton(const char *cp, struct in_addr *inp);
uint32_t ntohl(uint32_t netlong);

char *inet_ntoa(struct in_addr in);
uint32_t htonl(uint32_t hostlong);
]]

local C = ffi.C


local _M = {}

local ip2long = function(ip)
    local num = 0
    ip:gsub("%d+", function(s) num = num * 256 + tonumber(s) end)
    return num
end

local ip2long_c = function(ip)
    local inp = ffi.new("struct in_addr[1]")
    if C.inet_aton(ip, inp) ~= 0 then
        return tonumber(C.ntohl(inp[0].s_addr))
    end
    return nil
end

function _M.map()
    local ClientIP = ngx.req.get_headers()["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = ngx.req.get_headers()["X-Forwarded-For"]
        if ClientIP then
            local colonPos = string.find(ClientIP, ' ')
            if colonPos then
                ClientIP = string.sub(ClientIP, 1, colonPos - 1)
            end
        end
    end

    if ClientIP == nil then
        ClientIP = ngx.var.remote_addr
    end
    if ClientIP then
        local status, res = pcall(ip2long_c, ClientIP)
        if status then
            ClientIP = res
        else
            ClientIP = ip2long(ClientIP)
        end
    end
    return ClientIP
end

return _M