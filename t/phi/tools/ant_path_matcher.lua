---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Administrator.
--- DateTime: 2018/4/23 11:01
---
package.path = "E:/work/phi/lib/?.lua;E:/work/phi/phi/tools/ant_path_matcher.lua;;" .. package.path
local antMatcher = require "tools.ant_path_matcher"

antMatcher.match("/**/test/abc/", "/test")
local pattern1 = "/test/abc"
print("pattern [" .. pattern1 .. "]")
print("/te                    ========================= ", antMatcher.match(pattern1, "/te"))
print("/test                  ========================= ", antMatcher.match(pattern1, "/test"))
print("/test/abc              ========================= ", antMatcher.match(pattern1, "/test/abc"))
local pattern2 = "/test/abc/"
print("pattern [" .. pattern2 .. "]")
print("/test/abc              ========================= ", antMatcher.match(pattern2, "/test/abc"))
print("/test                  ========================= ", antMatcher.match(pattern2, "/test"))
print("/                      ========================= ", antMatcher.match(pattern2, "/"))
local pattern3 = "/**/test/abc/"
print("pattern [" .. pattern3 .. "]")
print("/foo/test/abc          ========================= ", antMatcher.match("/**/test/abc/", "/foo/test/abc/"))
print("/test                  ========================= ", antMatcher.match("/**/test/abc/", "/test"))
print("/                      ========================= ", antMatcher.match("/**/test/abc/", "/"))
print("/foo/bar/abc           ========================= ", antMatcher.match("/**/test/abc/", "/foo/bar/abc"))
print("/foo/bar/test/abc      ========================= ", antMatcher.match("/**/test/abc/", "/foo/bar/test/abc"))
local pattern4 = "/**/test/abc/**"
print("pattern [" .. pattern4 .. "]")
print("/test/abc/ab           ========================= ", antMatcher.match(pattern4, "/test/abc/ab"))
print("/test                  ========================= ", antMatcher.match(pattern4, "/test"))
print("/                      ========================= ", antMatcher.match(pattern4, "/"))
print("/foo/bar/abc           ========================= ", antMatcher.match(pattern4, "/foo/bar/abc"))
print("/foo/bar/test/abc      ========================= ", antMatcher.match(pattern4, "/foo/bar/test/abc"))
