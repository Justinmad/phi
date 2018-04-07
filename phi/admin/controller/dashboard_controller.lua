--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 10:42
-- 状态统计
--
local Response = require "core.response"
local config = require("Phi").configuration
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local type = type
local table_insert = table.insert
local table_concat = table.concat
local table_sort = table.sort
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function()
        return {}
    end
end

local dashboardController = {
    request_mapping = "admin",
    routerService = "",
    upstreamService = ""
}
function dashboardController:tree()
    local err
    local routers
    routers, err = self.routerService:getAllRouterPolicy(0, 1024);
    local result = { name = "Phi", children = new_tab(routers.count, 0), type = "phi" }
    local children = result.children
    if err then
        return Response.failure(err)
    end
    for k, router_data in pairs(routers.data) do
        -- 二级节点，hostname
        local tmpNode = new_tab(0, 4)
        table_insert(children, tmpNode)
        tmpNode.name = k
        -- 这是一条路由hostkey，允许编辑
        tmpNode.type = "host"
        tmpNode.router = router_data
        local ps = router_data.policies
        if ps then
            table_sort(router_data.policies, function(r1, r2)
                local o1 = tonumber(r1.order) or 0
                local o2 = tonumber(r2.order) or 0
                return o1 > o2
            end)
            -- 三级节点，policies
            tmpNode.children = new_tab(#ps + 1, 0)
            for _, p in ipairs(ps) do
                local tmpPolicyNode = new_tab(0, 6)
                -- 这是一条路由规则，允许编辑
                tmpPolicyNode.type = "policy"
                tmpPolicyNode.policy = p.policy
                tmpPolicyNode.host = k
                table_insert(tmpNode.children, tmpPolicyNode)
                local mapper = p.mapper
                if type(mapper) == "table" then
                    local cacheT = { mapper.type, mapper.tag, p.policy }
                    tmpPolicyNode.name = table_concat(cacheT, ":")
                    tmpPolicyNode.mapper = mapper.type
                    tmpPolicyNode.tag = mapper.tag
                else
                    tmpPolicyNode.mapper = mapper
                    tmpPolicyNode.name = mapper .. ":" .. p.policy
                end
                local rt = p.routerTable
                if type(rt) == "table" then
                    tmpPolicyNode.children = new_tab(#rt, 0)
                    for _, item in ipairs(rt) do
                        -- 四级节点 ups
                        local tmpUpsNode = new_tab(0, 4)
                        table_insert(tmpPolicyNode.children, tmpUpsNode)
                        tmpUpsNode.name = item.result
                        tmpUpsNode.calculation = p.policy
                        tmpUpsNode.condition = item.expression
                        tmpUpsNode.type = "phi_upstream"
                    end
                end
            end
        else
            tmpNode.children = new_tab(1, 0)
            router_data.policies = {}
        end
        local tmpPolicyNode = new_tab(0, 6)
        table_insert(tmpNode.children, tmpPolicyNode)
        tmpPolicyNode.name = router_data.default
        tmpPolicyNode.value = router_data.default
        tmpPolicyNode.router = router_data
        tmpPolicyNode.host = k
        -- 这是一个默认值，不允许删除
        tmpPolicyNode.type = "policy"
        tmpPolicyNode.stable = true
    end
    return Response.success(result, nil, true)
end

function dashboardController:upsTree()
    local upstreams = self.upstreamService:getAllUpsInfo()
    local root = new_tab(0, 2)
    root.name = "upstream"
    root.children = new_tab(50, 0)
    root.type = "ups_root"
    for k, ups_info in pairs(upstreams) do
        local tmpUpsNode = new_tab(0, 5)
        table_insert(root.children, tmpUpsNode)
        tmpUpsNode.name = k
        tmpUpsNode.type = "upstream"
        -- 五级节点 servers
        if ups_info.strategy then
            -- 这是一个自定义upstream,允许编辑
            local servers = ups_info.servers
            tmpUpsNode.upstream = ups_info
            tmpUpsNode.strategy = ups_info.strategy
            tmpUpsNode.mapper = type(ups_info.mapper) == "table" or ups_info.mapper or ups_info.mapper.type
            tmpUpsNode.tag = type(ups_info.mapper) == "table" or nil or ups_info.mapper.tag
            tmpUpsNode.children = {}
            for _, s in ipairs(servers) do
                local tmpServerNode = new_tab(0, 6)
                table_insert(tmpUpsNode.children, tmpServerNode)
                tmpServerNode.name = s.name
                tmpServerNode.ups = k
                tmpServerNode.down = s.down or false
                -- 这是一个自定义server，允许编辑
                tmpServerNode.type = "server"
                tmpServerNode.server = s
                if s.down then
                    tmpServerNode.itemStyle = {
                        borderColor = "#FF0000"
                    }
                else
                    tmpServerNode.itemStyle = {
                        borderColor = "green"
                    }
                end
            end
        else
            tmpUpsNode.stable = true
            tmpUpsNode.children = new_tab(#ups_info, 0)
            for _, s in ipairs(ups_info) do
                local tmpServerNode = new_tab(0, 7)
                table_insert(tmpUpsNode.children, tmpServerNode)
                tmpServerNode.name = s.name
                tmpServerNode.ups = k
                -- 这是一个固定server，不能编辑，但是可以临时UP/DOWN
                tmpServerNode.type = "server"
                tmpServerNode.stable = true
                tmpServerNode.down = s.down or false
                tmpServerNode.server = s
                if s.down then
                    tmpServerNode.itemStyle = {
                        borderColor = "red"
                    }
                else
                    tmpServerNode.itemStyle = {
                        borderColor = "green"
                    }
                end
            end
        end
    end
    return Response.success(root)
end

function dashboardController.mappers()
    return Response.success(config.enabled_mappers)
end

function dashboardController.policies()
    return Response.success(config.enabled_policies)
end

function dashboardController.balancers()
    return Response.success({ "resty_chash", "roundrobin" })
end
return dashboardController