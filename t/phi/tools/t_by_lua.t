use Test::Nginx::Socket::Lua;
repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

our $HttpConfig = <<'_EOC_';
    lua_package_path 'lib/?.lua;;';
_EOC_

no_long_string();

run_tests();

__DATA__

=== TEST 1: Validator.required
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local antMatcher = require "tools.ant_path_matcher"
            antMatcher.match("/**/test/abc/", "/test")
            local path = ngx.req.get_uri_args()["path"]
            local patt = ngx.req.get_uri_args()["patt"]
            if path and patt then
                ngx.say("path:[" .. path .. "]=====pattern:[" .. patt .. "]=====" .. tostring(antMatcher.match(patt, path)))
            end
        ';
    }
--- request
GET /t?path=/foo/bar&patt=/**/foo/bar/**
--- response_body
true
'blah' claim is required.
--- no_error_log
[error]