#!/usr/bin/env bash
# assuming your luajit is installed to /opt/luajit:
ngx_src=$1

cd $ngx_src

export LUAJIT_LIB=/usr/local/lib

# assuming you are using LuaJIT v2.1:
export LUAJIT_INC=/usr/local/include/luajit-2.1

mkdir tmp
wget -O lua-nginx-module-0.10.11.tar.gz https://github.com/openresty/lua-nginx-module/archive/v0.10.11.tar.gz
tar -xvf lua-nginx-module-0.10.11.tar.gz
export lua_nginx_module=$ngx_src/tmp/lua-nginx-module-0.10.11

wget -O lua-upstream-nginx-module-0.07.tar.gz https://github.com/openresty/lua-upstream-nginx-module/archive/v0.07.tar.gz
tar -xvf lua-upstream-nginx-module-0.07.tar.gz
export lua_upstream_nginx_module=$ngx_src/tmp/lua-upstream-nginx-module-0.07


# Here we assume you would install you nginx under /opt/nginx/.

mkdir -p /home/phi-0.0.1

./configure --prefix=/home/phi-0.0.1 \
    --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
    --add-module=$lua_nginx_module \
    --add-module=$lua_upstream_nginx_module

make -j2
make install