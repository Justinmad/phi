---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2018/4/18 17:25
---

--[[
    {
      "hostkey": "www.sample.com",
      "mapper": {
        "header":"X-JWT-TOKEN"
      },
      "secret": "~!+_qwd23KASXZLPQWE,3%())<>,.!",
      "alg": "HS256",
      "issuers":[],
      "include": ["/asd/*"],
      "exclude": []
    }
]]
local base_component = require "component.base_component"
local get_host = require("utils").getHost
local cjson = require "cjson.safe"
local response = require "core.response"
local mlcache = require "resty.mlcache"
local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local CONST = require("core.constants")
local ant_path_matcher = require("tools.ant_path_matcher")
local pretty_write = require("pl.pretty").write
local mapper_holder = require("Phi").mapper_holder
local uri_mapper = mapper_holder["uri"]
local PHI_EVENTS_DICT_NAME = CONST.DICTS.PHI_EVENTS
local ipairs = ipairs
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local EVENTS = {
    SOURCE = "jwt-auth",
    REBUILD = "rebuild"
}

local alg_enum = {
    HS256 = "HS256",
    HS512 = "HS512",
    RS256 = "RS256",
    RS512 = "RS512"
}

local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local INFO = ngx.INFO
local NOTICE = ngx.NOTICE
local LOGGER = ngx.log
local ngx_now = ngx.now
local worker_pid = ngx.worker.pid
local CACHE_KEY_PREFIX = "phi:plugin:jwt-auth:"

local jwt_auth = base_component:extend()

jwt_auth._version = "0.0.1"
jwt_auth.lrucache_size = 1000
jwt_auth.shared_dict_name = "jwt-auth"

function jwt_auth:init_worker(observer)
    self.observer = observer
    -- 注册关注事件handler到指定事件源
    observer.register(function(data, event, source, pid)
        if worker_pid() == pid then
            LOGGER(NOTICE, "do not process the event send from self")
        else
            -- 更新缓存
            if event == EVENTS.REBUILD then
                self.cache:update()
                self:getValidator(data)
            end
            LOGGER(DEBUG, "received event; source=", source,
                    ", event=", event,
                    ", data=", pretty_write(data),
                    ", from process ", pid)
        end
    end, EVENTS.SOURCE)
end

local function createValidator(schema)
    return function(ctx)
        if schema.skip then
            return { verified = true }
        end

        local jwt_token = mapper_holder:map(ctx, schema.mapper)
        local include, exclude
        for _, patt in ipairs(schema.include) do
            if ant_path_matcher.match(patt, uri_mapper.map(ctx)) then
                include = true
            end
        end
        for _, patt in ipairs(schema.exclude) do
            if ant_path_matcher.match(patt, uri_mapper.map(ctx)) then
                exclude = true
            end
        end
        if include and not exclude then
            return jwt:verify(schema.secret, jwt_token, {
                exp = validators.is_not_expired(),
                iss = validators.equals_any_of(schema.issuers)
            })
        else
            return { verified = true }
        end
    end
end

local function getFromDb(redis, hostkey)
    local redisCacheKey = CACHE_KEY_PREFIX .. hostkey
    local res, err = redis:get(redisCacheKey)
    if err then
        -- 查询出现错误，10秒内不再查询，放行
        LOGGER(ERR, "could not retrieve jwt-auth schema:", err)
        return { skip = true }, nil, 10
    end
    return cjson.decode(res) or { skip = true }
end

function jwt_auth:getValidator(hostkey)
    local result, err = self.cache:get(hostkey, nil, getFromDb, self.redis, hostkey)
    return result, err
end

-- add a new jwt-auth to an hostkey
function jwt_auth:add(hostkey, schema)
    local ok, err
    if not alg_enum[schema.alg] then
        return false, "Unsupported encryption algorithm !"
    end
    local redisCacheKey = CACHE_KEY_PREFIX .. hostkey
    ok, err = self.redis:set(redisCacheKey, cjson.encode(schema))
    if not ok then
        LOGGER(ERR, "save jwt-auth schema failed")
        return ok, err
    end
    -- refresh cache
    self.observer.post(EVENTS.SOURCE, EVENTS.REBUILD, hostkey)
    return true, nil
end

-- jwt sign for dev
function jwt_auth:sign(hostkey, alg, secret, expire, sub)
    if not alg_enum[alg] then
        return false, "Unsupported encryption algorithm !"
    end

    return jwt:sign(
            secret,
            {
                header = { typ = "JWT", alg = alg_enum[alg] },
                payload = { sub = sub, exp = ngx_now() + expire, aud = hostkey, iss = "phi" }
            }
    )
end

-- jwt认证
function jwt_auth:rewrite(ctx)
    self.super.rewrite(self)
    local hostkey = get_host(ctx)
    local jwt_obj = self:getValidator(hostkey)(ctx)
    if not jwt_obj.verified then
        local msg = jwt_obj.reason or "invalid jwt string"
        LOGGER(INFO, msg)
        return response.failure(msg)
    end
end

function jwt_auth:new(ref, config)
    if type(ref) ~= "table" then
        error("redis obj is nil ?")
    end
    self.super.new(self, "jwt-auth")
    self.redis = ref
    self.order = config.order

    local cache, err = mlcache.new("jwt-auth-cache", self.shared_dict_name, {
        lru_size = self.lrucache_size or 1000,
        ttl = 0,
        neg_ttl = 0,
        resty_lock_opts = {
            exptime = 10,
            timeout = 5
        },
        ipc_shm = PHI_EVENTS_DICT_NAME,
        l1_serializer = createValidator
    })
    if err then
        error("could not create mlcache for jwt-auth cache ! err :" .. err)
    end
    self.cache = cache
    return self
end

return jwt_auth