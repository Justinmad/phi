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

-- windows下未找到inet_aton函数类似功能，暂时使用这个函数替代
local function ip2long(ip)
    local num = 0
    ip:gsub("%d+", function(s) num = num * 256 + tonumber(s) end)
    return num
end

-- 这里有BUG，暂时不使用此方法
--local function check_ip(ip)
--    local list = stringx.split(ip, ".")
--    for _, no in ipairs(list) do
--        if not tonumber(no) then
--            return nil
--        end
--    end
--    return list
--end
--local bit = require "bit"
--local lshift = bit.lshift
--local bor = bit.bor
--local function ip2long(ip_addr)
--    print("ip:", ip_addr)
--    local blocks = check_ip(ip_addr) or error("Invalid IP-Address")
--    -- 避免长整型溢出，导致出现负数
--    local ips = 0
--    ips = ffi.new("int64_t", ips)
--    for _, i in ipairs(blocks) do
--        ips = bor(lshift(ips, 8), i);
--    end
--    return ips
--end

local ip2long_c = function(ip)
    local inp = ffi.new("struct in_addr[1]")
    if C.inet_aton(ip, inp) ~= 0 then
        return tonumber(C.ntohl(inp[0].s_addr))
    end
    return nil
end

function _M.map(ctx, tag)
    local headers = ngx.req.get_headers()
    local ClientIP = headers["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = headers["X-Forwarded-For"]
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
    --    local ClientIP = ngx.var.remote_addr
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