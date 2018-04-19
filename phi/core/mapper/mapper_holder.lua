--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/17
-- Time: 18:02
-- 预加载所有允许使用的mapper，不建议使用需要解析请求体的api，这会增加额外的开销
--
local LOGGER = ngx.log
local ERR = ngx.ERR
local require = require
local type = type
local ipairs = ipairs
local getn = table.getn
local insert = table.insert
local concat = table.concat
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end
local _M = {}

function _M:new(config)
    if type(config) == "table" then
        for _, name in ipairs(config) do
            name = name:lower()
            LOGGER(ERR, "[MAPPER_HOLDER]加载:" .. name)
            local mapper = require("core.mapper." .. name .. "_mapper")
            _M[name] = mapper
        end
    else
        config = config:lower()
        LOGGER(ERR, "[MAPPER_HOLDER]加载:" .. config)
        local mapper = require("core.mapper." .. config .. "_mapper")
        _M[config] = mapper
    end
    return setmetatable({}, { __index = _M })
end

local function doMap(self, ctx, mapperTable)
    local typeStr = type(mapperTable) == "string" and mapperTable or mapperTable.type
    if type(ctx) ~= "table" or type(typeStr) ~= "string" then
        LOGGER(ERR, "ctx参数不正确？")
        return nil, "ctx参数不正确？"
    end
    local mapper = self[typeStr:lower()]
    if not mapper then
        return nil, "未查询到可用的mapper:" .. typeStr
    end
    return mapper.map(ctx, mapperTable.tag)
end

function _M:map(ctx, mapperT)
    if type(mapperT) == "string" then
        return doMap(self, ctx, mapperT)
    end
    local len = getn(mapperT)
    if len == 0 then
        return doMap(self, ctx, mapperT)
    elseif getn(mapperT) >= 1 then
        local tmp = new_tab(len, 0)
        for _, m in ipairs(mapperT) do
            local v, err = doMap(self, ctx, m)
            if err then
                return nil, err
            end
            insert(tmp, v)
        end
        return concat(tmp, ":")
    else
        return nil, "错误的mapper数据格式!"
    end
end

return _M

