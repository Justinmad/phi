# assuming your luajit is installed to /opt/luajit:
export LUAJIT_LIB=/opt/luajit/lib

# assuming you are using LuaJIT v2.1:
export LUAJIT_INC=/opt/luajit/include/luajit-2.1

export lua_upstream_nginx_module=/home/young/soft/lua-upstream-nginx-module-0.07

export lua_nginx_module=/home/young/soft/resty-lib/lua-nginx-module-0.10.12rc2

# Here we assume you would install you nginx under /opt/nginx/.
./configure --prefix=/home/young/soft/nginx \
    --with-ld-opt="-Wl,-rpath,$LUAJIT_LIB" \
    --add-module=/home/young/soft/resty-lib/lua-nginx-module-0.10.12rc2 \
    --add-module=/home/young/soft/resty-lib/lua-upstream-nginx-module-0.07

make -j2
make install