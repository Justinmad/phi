--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 15:46
-- 初始化worker
--

local ev = require "resty.worker.events"

local ok, err = ev.configure {
    shm = "phi_events",     -- defined by "lua_shared_dict"
    timeout = 2,            -- life time of event data in shm
    interval = 1,           -- poll interval (seconds)

    wait_interval = 0.010,  -- wait before retry fetching event data
    wait_max = 0.5,         -- max wait time before discarding event
}
if not ok then
    ngx.log(ngx.ERR, "failed to start event system: ", err)
    return
end

PHI.observer = ev
PHI.router_service:init_worker(ev)