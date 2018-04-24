---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2018/4/18 17:26
---
local jwt_handler = require("component.jwt.handler")
local response = require("core.response")

local _M = {
    request_mapping = "/jwt",
}

function _M:add(req, res, next)
    local hostkey = req.body.hostkey
    local schema = req.body.schema
    if not hostkey or not schema or not schema.mapper or not schema.secret or not schema.alg or not schema.issuers or not schema.include or not schema.exclude then
        return response.failure("缺少必要的参数！")
    end
    local ok, err = jwt_handler:add(hostkey, schema)
    if not ok then
        return response.failure(err)
    end
    return response.success()
end

_M.sign = {
    method = "post",
    handler = function(self, req, res, next)
        local hostkey = req.body.hostkey
        local alg = req.body.alg
        local secret = req.body.secret
        local expire = tonumber(req.body.expire)
        local sub = req.body.sub
        if not hostkey or not alg or not secret or not expire then
            return response.failure("缺少必要的参数！")
        end
        local jwt_token, err = jwt_handler:sign(hostkey, alg, secret, expire, sub)
        if not jwt_token then
            return response.failure(err)
        end
        return response.success(jwt_token)
    end
}

return _M