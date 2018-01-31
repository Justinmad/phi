--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/18
-- Time: 20:09
-- cookie工具
--

local M = {}

-- set a cookie
local function set(name, value, expires)
    -- format the date
    if type(expires) == "number" then
        expires = os.date("!%a, %d-%m-%Y %H:%M:%S GMT", expires)
    end

    -- locals
    local set_cookie = ngx.header.set_cookie
    local header = name .. '=' .. value .. ';path=/'
    if expires then
        header = header .. ";expires=" .. expires
    end

    -- add the cookie
    if set_cookie == nil then
        ngx.header['Set-Cookie'] = { header }
    elseif type(set_cookie) == "string" then
        ngx.header['Set-Cookie'] = { set_cookie, header }
    elseif type(set_cookie) == "table" then
        table.insert(set_cookie, header)
    else
        return false
    end

    -- Set caching headers whenever a cookie is set
    local cc = ngx.header['Cache-Control']
    if cc == nil or type(cc) ~= "string" or not ngx.re.find(cc, "no-cache", "oij") then
        ngx.header.cache_control = "private"
    end
    ngx.header.pragma = "nocache"

    return true
end

M.set = set

-- delete a cookie
-- set the value to "deleted"
function M.delete(name, expires)
    set(name, "deleted", expires or 0)
end

-- get the value of a cookie fromt he request
function M.get(name)
    return ngx.var["cookie_" .. name]
end

return M