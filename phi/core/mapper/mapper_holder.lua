--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 18:02
-- To change this template use File | Settings | File Templates.
--
local _M = {}
local mt = { __index = _M }
local LOGGER = ngx.log
local DEBUG = ngx.DEBUG

function _M:new(config)
    if type(config) == "table" then
        for _, name in ipairs(config) do
            name = name:lower()
            LOGGER(DEBUG, "[MAPPER_HOLDER]加载:" .. name)
            local mapper = require("core.mapper." .. name .. "_mapper")
            _M[name] = mapper
        end
    else
        config = config:lower()
        LOGGER(DEBUG, "[MAPPER_HOLDER]加载:" .. config)
        local mapper = require("core.mapper." .. config .. _mapper)
        _M[config] = mapper
    end
    return setmetatable({}, mt)
end

function _M:map(type, arg)
    local mapper = self[type]
    if not mapper then
        return nil, "未查询到可用的mapper:" .. type
    end
    return mapper.map(arg)
end

return _M

