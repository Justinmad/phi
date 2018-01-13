--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/6
-- Time: 16:33
-- 用来做路由控制，根据制定规则进行访问控制：如灰度发布等.
--
local router = {};

function router.access()
    local data = PHI.dao:info()
    ngx.say("this is access by lua block : " .. data)
end

return router;