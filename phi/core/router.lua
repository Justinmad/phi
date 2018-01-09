--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/6
-- Time: 16:33
-- 用来做分流，根据制定规则进行流量分配.
--
local router = {};

function router.access()
    print("this is router access ==============================>");
end

return router;