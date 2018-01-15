--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/1/6
-- Time: 16:33
-- 用来做路由控制，根据制定规则进行访问控制：如灰度发布等.
--

local router = {}

local function before()
end

local function after()
end

-- 获取请求头中Host的值，使用此字段作为默认情况下的路由key
-- 特殊情况下可以设置ngx.var.hostkey的值作为路由key
local getHost = function()
    local host = ngx.req.get_headers()['Host']
    if not host then return nil end
    local hostkey = ngx.var.hostkey
    if hostkey then
        return hostkey
    else
        --location 中不配置hostkey时
        return host
    end
end

-- 主要:根据host查找路由规则，根据对应规则对本次请求中的backend变量进行赋值，达到路由到指定upstream的目的
function router.access()
    local hostkey = getHost();
    if hostkey then
        local policies = PHI.dao:selectRouterPolicy(hostkey);
        if policies then
            print(policies.default, "----", policies.upstream_name_1[2])
        end
    else
        ngx.log(ngx.ALERT, "hostkey为nil，无法执行路由操作")
    end
end

return router;