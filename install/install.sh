#!/usr/bin/env bash
ngx_src=$1
if [ ! -d "$ngx_src" ];then
    echo "$ngx_src is not exists"
    exit 1
fi
mkdir -p ${ngx_src}/tmp

# download and install LuaJIT-2.1.0-beta3.tar.gz
cd ${ngx_src}/tmp
wget -O LuaJIT-2.1.0-beta3.tar.gz http://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz
tar -xvf LuaJIT-2.1.0-beta3.tar.gz
cd LuaJIT-2.1.0-beta3
make clean
make uninstall
make -j2 CCDEBUG=-g
make install
export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

cd ${ngx_src}/tmp
# download lua-nginx-module-0.10.11.tar.gz
wget -O lua-nginx-module-0.10.11.tar.gz https://github.com/openresty/lua-nginx-module/archive/v0.10.11.tar.gz
tar -xvf lua-nginx-module-0.10.11.tar.gz
export LUA_NGINX_MODULE=${ngx_src}/tmp/lua-nginx-module-0.10.11

cd ${ngx_src}/tmp
# download lua-upstream-nginx-module-0.07.tar.gz
wget -O lua-upstream-nginx-module-0.07.tar.gz https://github.com/openresty/lua-upstream-nginx-module/archive/v0.07.tar.gz
tar -xvf lua-upstream-nginx-module-0.07.tar.gz
export LUA_UPSTREAM_NGINX_MODULE=${ngx_src}/tmp/lua-upstream-nginx-module-0.07

# make install nginx with lua module
cd ${ngx_src}
mkdir -p /home/phi-0.0.1
./configure --prefix=/home/phi-0.0.1 \
    --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
    --with-http_stub_status_module \
    --add-module=${LUA_NGINX_MODULE} \
    --add-module=${LUA_UPSTREAM_NGINX_MODULE}
make -j2
make install