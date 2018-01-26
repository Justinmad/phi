--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/26
-- Time: 20:23
-- To change this template use File | Settings | File Templates.
--
local pl_config = require "pl.config"
local _M = {}

function _M.init(config_locations)
    local context = {}
    if type(config_locations) == "table" and #config_locations > 0 then
        for _, path in ipairs(config_locations) do
            local beanDefinition = pl_config.read(path)
            for id, definition in pairs(beanDefinition) do
                local path = definition.path
                local class = require(path)
                local properties = definition.properties
                local autowire = definition.autowire
                local bean
                if type(class.new) ~= "function" then
                    bean = class
                    context[id] = class
                else
                    if properties then
                        if autowire then

                        bean = class:new(properties)
                        end
                    end
                end
            end
        end
    elseif type(config_locations) == "string" then
    else
        error("非法的配置文件路径！")
    end
end

return _M
