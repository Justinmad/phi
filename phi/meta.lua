--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/8
-- Time: 15:41
-- 项目版本控制.
--

local version = setmetatable({
    major = 0,
    minor = 0,
    patch = 1,
}, {
    __tostring = function(t)
        return string.format("%d.%d.%d%s", t.major, t.minor, t.patch,
            t.suffix and t.suffix or "")
    end
})

return {
    _NAME = "phi",
    _VERSION = tostring(version),
    _VERSION_TABLE = version,
    -- 以下版本号是我在开发时使用的版本
    _DEPENDENCIES = {
        nginx = { "1.11.2.4" },
        lua_nginx_module = { "0.10.12" }
    }
}
