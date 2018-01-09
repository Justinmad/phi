--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 16:11
-- 初始化数据，读取配置等等，提前加载一些模块以提高运行效率
--

do
    -- 确认nginx配置中是否已经声明了程序运行时所必须的lua_shared_dict共享缓存
    local constants = require "core.constants"

    for _, dict in ipairs(constants.DICTS) do
        if not ngx.shared[dict] then
            return error("missing shared dict '" .. dict .. "' in Nginx " ..
                    "configuration, are you using a custom template? " ..
                    "Make sure the 'lua_shared_dict " .. dict .. " [SIZE];' " ..
                    "directive is defined.")
        end
    end
end

require "resty.core"
require "cjson.safe"
