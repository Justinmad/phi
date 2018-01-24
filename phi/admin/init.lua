--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 16:11
-- 初始化admin
--
if not PHI then
    error("PHI未初始化完成？")
end

local admin = require "admin.phi_admin"
-- 加载配置，创建api-mapping
local CONST = require "core.constants"
local BASE_PATH = CONST.ADMIN.PATH_BASE .. "/"
local CTRL = CONST.ADMIN.CONTROLLERS

for _, class in ipairs(CTRL) do
    local ctrl = require(BASE_PATH .. class)
    local base_url = "/" .. (ctrl.mapping or class)
    for k, v in pairs(ctrl) do
        -- 不加载元表数据
        if k:find("__") ~= 1 then
            -- 如果是函数，直接映射到路径
            local mapping
            if type(v) == "function" then
                mapping = base_url .. "/" .. k
                admin[mapping] = v
                print("==============>" .. mapping)
            elseif type(v) == "table" then
                -- 如果是表，按照表参数映射
                if type(v.handler) ~= "function" then
                    error("非法的handler类型！type:" .. tostring(v.handler))
                end
                if (v.mapping) then
                    mapping = base_url .. "/" .. v.mapping
                else
                    mapping = base_url .. "/" .. k
                end
                if v.method then
                    if not admin[mapping] then
                        admin[mapping] = {}
                    end
                    admin[mapping][v.method] = v.handler
                else
                    admin[mapping] = v.handler
                end
            else
                print("skip==============>" .. mapping)
            end
        end
    end
end

return admin