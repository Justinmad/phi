--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/23
-- Time: 15:46
-- 初始化worker
--
do
    local ev = require "resty.worker.events"
    local PHI_EVENTS = require("core.constants").DICTS.PHI_EVENTS
    local ok, err = ev.configure {
        shm = PHI_EVENTS,       -- defined by "lua_shared_dict"
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
    local context = PHI.context
    for _, bean in pairs(context) do
        if type(bean.init_worker) == "function" then
            bean:init_worker(ev)
        end
    end
end