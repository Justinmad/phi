--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/26
-- Time: 10:42
-- 状态统计
--
local Response = require "core.response"
local CONST = require "core.constants"
local config = require("Phi").configuration
local GET = CONST.METHOD.GET
local POST = CONST.METHOD.POST
local pairs = pairs
local ipairs = ipairs
local type = type
local table_insert = table.insert
local table_concat = table.concat
local table_sort = table.sort
local pretty_write = require("pl.pretty").write
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
                local o1 = r1.order or 0
                local o2 = r2.order or 0
                return o1 > o2
            end)
            -- 三级节点，policies
            tmpNode.children = new_tab(#ps + 1, 0)
            for _, p in ipairs(ps) do
                local tmpPolicyNode = new_tab(0, 4)
                -- 这是一条路由规则，允许编辑
                tmpPolicyNode.type = "policy"
                tmpPolicyNode.router = router_data
                tmpPolicyNode.host = k
                table_insert(tmpNode.children, tmpPolicyNode)
                local mapper = p.mapper
                if type(mapper) == "table" then
                    local cacheT = { mapper.type, mapper.tag, p.policy }
                    tmpPolicyNode.name = table_concat(cacheT, ":")
                else
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
                        tmpUpsNode.value = pretty_write(item.expression)
                        local servers = self.upstreamService:getUpstreamServers(item.result)
                        tmpUpsNode.type = "upstream"
                        if type(servers) == "table" then
                            -- 五级节点 servers
                            if servers.strategy then
                                -- 这是一个自定义upstream,允许编辑
                                tmpUpsNode.children = {}
                                for k, v in pairs(servers) do
                                    if k ~= "strategy" and k ~= "mapper" then
                                        local tmpServerNode = new_tab(0, 5)
                                        table_insert(tmpUpsNode.children, tmpServerNode)
                                        tmpServerNode.name = k
                                        tmpServerNode.info = v
                                        tmpServerNode.ups = item.result
                                        -- 这是一个自定义server，允许编辑
                                        tmpServerNode.type = "server"
                                        if v.down then
                                            tmpServerNode.itemStyle = {
                                                borderColor = "#FF0000"
                                            }
                                        else
                                            tmpServerNode.itemStyle = {
                                                borderColor = "green"
                                            }
                                        end
                                    end
                                end
                            else
                                tmpUpsNode.stable = true
                                tmpUpsNode.children = new_tab(#servers, 0)
                                for _, s in ipairs(servers) do
                                    local tmpServerNode = new_tab(0, 5)
                                    table_insert(tmpUpsNode.children, tmpServerNode)
                                    tmpServerNode.name = s.name
                                    tmpServerNode.info = s
                                    -- 这是一个固定server，不能编辑，但是可以临时UP/DOWN
                                    tmpServerNode.type = "server"
                                    tmpServerNode.stable = true
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
                        else
                            tmpUpsNode.stable = true
                        end
                    end
                end
            end
        else
            tmpNode.children = new_tab(1, 0)
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
    return Response.success(result)
end

function dashboardController.mappers()
    return Response.success(config.enabled_mappers)
end

function dashboardController.policies()
    return Response.success(config.enabled_policies)
end
return dashboardController