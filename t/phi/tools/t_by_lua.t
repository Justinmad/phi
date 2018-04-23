
local antMatcher = require "tools.ant_path_matcher"
antMatcher.match("/**/test/abc/", "/test")
local path = ngx.req.get_uri_args()["path"]
local patt = ngx.req.get_uri_args()["patt"]
if path and patt then
    ngx.say("path:[" .. path .. "]=====pattern:[" .. patt .. "]=====" .. tostring(antMatcher.match(patt, path)))
end
