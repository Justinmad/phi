--
-- Created by IntelliJ IDEA.
-- User: yangyang.zhang
-- Date: 2018/2/25
-- Time: 15:24
-- 简单hash算法
--
local _ok, new_tab = pcall(require, "table.new")
if not _ok or type(new_tab) ~= "function" then
    new_tab = function() return {} end
end
local ngx_chash = ngx.crc32_long
local floor = math.floor

local function rehash(server_list)
    local total_weight = 0
    for _, w in pairs(server_list) do
        total_weight = total_weight + w
    end
    local nodes = new_tab(0, 100)
    -- 重新分配hash节点
    local i = 1
    for s, w in pairs(server_list) do
        local count = 100 * w / total_weight
        count = count < 1 and 1 or floor(count)
        for c = 1, count do
            nodes[i] = s
            i = i + 1
        end
    end
    return nodes
end

local _M = {}

function _M:find(key)
    local hash = ngx_chash(key);
    hash = (hash % #(self.nodes)) + 1
    return self.nodes[hash]
end

function _M:set(id, weight)
    self.server_list[id] = weight
    self.nodes = rehash(self.server_list)
end

local class = {}

function class:new(server_list)
    return setmetatable({ nodes = rehash(server_list), server_list = server_list }, { __index = _M })
end

return class
