#!/usr/bin/env bash
# assuming your luajit is installed to /opt/luajit:
export LUAJIT_LIB=/usr/local/lib

# assuming you are using LuaJIT v2.1:
export LUAJIT_INC=/usr/local/include/luajit-2.1

export lua_upstream_nginx_module=/home/tengine-2.2.0/lua-upstream-nginx-module-0.07

export lua_nginx_module=/home/tengine-2.2.0/lua-nginx-module-0.10.11

export ngx_src=/home/tengine-2.2.0

# Here we assume you would install you nginx under /opt/nginx/.

mkdir -p /home/phi-0.0.1

cd $ngx_src

./configure --prefix=/home/phi-0.0.1 \
    --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
    --add-module=$lua_nginx_module \
    --add-module=$lua_upstream_nginx_module

make -j2
make install