--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/3
-- Time: 14:58
-- To change this template use File | Settings | File Templates.
--
ngx.say("=================")
local redis = require('resty.redis');
local redDb = redis:new();

ok, err = redDb:connect('127.0.0.1', 6379)
if ok then redDb:select(1)
else ngx.say(err);
end

redDb:set('test:abc', 'test-value');

local value = redDb:get('test:abc');

ngx.say(value);
ngx.say("adsadsasdasdasd")