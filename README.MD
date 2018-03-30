## 项目简介
基于openresty+nginx的api网关，实现了基本的动态路由、动态upstream、负载均衡、限流、降级的功能，借鉴kong的插件扩展策略，提供了可供自由添加的插件机制
## 目录
- [**安装**](#安装)
- [**启动和配置**](#启动和配置)
- [**启动管理控制台**](#启动管理控制台)
- [**启动统计面板**](#启动统计面板)
- [**快速开始**](#快速开始)
- [**管理控制台API**](#管理控制台api)
    - [**枚举值**](#枚举值)
    - [**Router**](#router)
    - [**Dynamic Upstream**](#dynamicupstream)
    - [**Rate Limiting**](#rateLimiting)
    - [**Service Degradation**](#servicedegradation)
- [**性能测试**](#性能测试)
- [**使用的第三方lua库或工具**](#使用的第三方lua库或工具)

## 安装
- 项目运行依赖[[OpenResty]]，安装了OpenResty的情况下可以跳过此安装步骤
- 自行编译[[lua-nginx-module]]、[[lua-upstream-nginx-module]]的Nginx，以及lua或者luajit
    ```bash
      # 你可以执行install目录下的install.sh来完成一键安装。项目默认将被安装在/home/phi-0.0.1目录下
      ./install.sh ${path_to_nginx_src}
    ```
- 请将/home/phi-0.0.1/sbin加入环境变量

## 启动和配置
- bin目录下的phi：
    - 用法: phi start|stop|restart|reload|test
    - 可选参数 :
        - -D: 启动远程debug模式，默认占用端口8172,使用参考：[[ZeroBrane Studio]]，[[EmmyLua]]
        - -H: 远程debug 主机名，默认localhost
        - -P: 远程debug 端口,默认8172
        - -p: nginx启动目录，同nginx -p参数
        - -c: nginx启动配置文件名称，同nginx -c参数
- 你也可以使用nginx启动命令来启动项目
- 你也可以自行指定nginx配置文件，但需要在你已存在的nginx配置中添加如下内容
    - Nginx 配置
        - 在nginx配置中添加如下内容
        ```nginx
            # 需要安装luajit/lua，xxx表示项目根路径，需要在nginx/tengine编译时添加如下模块lua_nginx_module(0.10.11)和lua_upstream_nginx_module(0.07)，安装方式参考install/install.sh
            lua_package_path '../openresty/?.lua;../phi/?.lua;../lib/?.lua;;';
            lua_package_cpath '../openresty/?.so;../lib/?.so;;';
            # 如果使用了openresty，那么只需引入下面的包
            #lua_package_path '../phi/?.lua;../lib/?.lua;;';
            #lua_package_cpath '../lib/?.so;;';
            #生产环境务必开启
            lua_code_cache on;
            # 共享内存的大小按需调整
            lua_shared_dict phi                     5m;
            lua_shared_dict phi_events              5m;
            lua_shared_dict phi_lock                5m;
            lua_shared_dict phi_router              10m;
            lua_shared_dict phi_upstream            10m;
            lua_shared_dict phi_limiter             10m;
            lua_shared_dict phi_limit_req           128m;
            lua_shared_dict phi_limit_conn          128m;
            lua_shared_dict phi_limit_count         128m;
            #lua入口文件
            init_by_lua_file ../entry_lua_file/init_by_lua.lua;
            init_worker_by_lua_file ../entry_lua_file/init_worker_by_lua.lua;
            log_by_lua_file ../entry_lua_file/log_by_lua.lua;
            server {
                listen 8080;
                location / {
                    set $backend '';
                    rewrite_by_lua_file ../entry_lua_file/rewrite_by_lua.lua;
                    access_by_lua_file ../entry_lua_file/access_by_lua.lua;
                    proxy_http_version 1.1;
                    proxy_set_header Connection "";
                    proxy_pass http://$backend;
                }
            }
            upstream phi_upstream {
                server 0.0.0.1;
                balancer_by_lua_file ../entry_lua_file/balancer_by_lua.lua;
                # 请按需调整
                keepalive 2000;
            }
        ```
- Phi 配置
    - 项目启动默认会读取bin目录和conf目录下的phi.ini，你可以创建此文件用来覆盖项目的默认配置
    - phi/config/default_config.lua中定义了默认的配置项
    ```lua
        return {
            debug = true,                 -- 是否开启远程debug
            debug_host = "127.0.0.1",     -- debug的host
            debug_port = 8172,            -- 远程debug占用端口
            enabled_admin = true,         -- 是否启动管理控制台
            enabled_mio = true,           -- 是否启动统计面板
            enabled_policies = { "UNIQUE", "RANGE", "PREFIX", "SUFFIX", "COMPOSITE", "MODULO", "REGEX" }, -- 启用的policy规则
            enabled_mappers = { "HEADER", "URI_ARGS", "IP", "URI" }, -- 启用的mapper类型
            default_paths = {             -- 默认的配置文件加载路径 conf/phi.ini 或者./phi.ini
                current_path .. "phi.ini", conf_path .. "phi.ini"
            },
            application_context_conf = {  -- 默认的application容器配置路径 conf/application.ini 或者./application.ini
                current_path .. "application.ini", conf_path .. "application.ini"
            }
        }
    ```
    - 配置项读取优先级
        - 环境变量中对应的值,环境变量取值会在所有的key前面加PHI_,例如debug对应环境变量中的PHI_DEBUG的值
        - default_paths中指定的ini文件中配置的值
        - default_config.lua中指定的默认值
        
## 启动管理控制台
phi配置中enabled_admin=true,在nginx配置中添加如下server
```nginx
server {
    listen 12345;
    location / {
        default_type application/json;
        content_by_lua_file ../entry_lua_file/admin_content_by_lua.lua;
        log_by_lua_file ../entry_lua_file/log_by_lua.lua;
    }
}
```

## 启动统计面板
- 在执行Nginx的编译前的配置中请添加 --with-http_stub_status_module，[[OpenResty]]默认开启
- phi配置中enabled_mio=true,并在nginx配置中添加如下server
    ```nginx
    server {
            listen       9090;
            access_log logs/api_access.log main;
            error_log logs/api_error.log info;
            set  $template_root "";
            location = /favicon.ico {
                log_not_found off;
                access_log off;
            }
            # 静态文件
            location ~* /static/(.*) {
                alias ../static/$1;
            }
            location /robots.txt {
                return 200 'User-agent: *\nDisallow: /';
            }
            location = / {
                try_files '' ../static/index.html;
            }
            location / {
                content_by_lua_file ../lib/mio/api/main.lua;
            }
        }
    ```
- 统计面板截图
![dashborad](/static/image/dashboard.png)
- 更多可参考[[MIO]]，对源代码做了一些修改

## 快速开始
- 参考默认配置
    - 使用8080端口作为api网关入口
    - 使用12345端口作为管理控制台api入口
    - 将conf/vhost.conf引入nginx配置中，用来模拟后端服务器，分别占用5555、6666、7777、8888端口
- 添加一个api-server，使用主机名sample.com
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"hostkey": "sample.com","data": {"default": "127.0.0.1:5555"}}' \
        http://localhost:12345/router/add
    ```
    - 访问刚才添加的api server
    ```text
    curl -H 'content-type:application/json' -H 'Host:sample.com' http://localhost:8080
    ```
    返回内容
    ```text
        this is the fake backend peer... listen port 5555
    ```
- 添加一组命名为dynamic_ups的api server，负载均衡策略使用轮询，其它参考[[Load Balance]](#loadbalance)
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"upstreamName":"dynamic_ups","strategy":"roundrobin","mapper":"ip","servers":[{"name":"127.0.0.1:5555","info":{"weight":10}},{"name":"127.0.0.1:6666","info":{"weight":10}}]}' \
        http://localhost:12345/upstream/addOrUpdateUps
    ```
- 将主机名sample.com指向的api server修改为dynamic_ups，其它api参考[[Dynamic Upstream]](#dynamicupstream)
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"hostkey": "sample.com","data": {"default": "dynamic_ups"}}' \
        http://localhost:12345/router/add
    ```
    - 访问刚才添加的api server
    ```text
    curl -H 'content-type:application/json' -H 'Host:sample.com' http://localhost:8080
    ```
    - 请求返回内容
    ```text
        this is the fake backend peer... listen port 5555
    ```
    - 再次请求返回内容
    ```text
        this is the fake backend peer... listen port 6666
    ```
- 对主机名sample.com添加一条路由规则，取请求头中X-UID的值，值尾数为8的请求转发到8888端口，值尾数为7的请求转发到7777端口，其它请求转发到default中的dynamic_ups中进行负载均衡，其它路由规则参考[[Router]](#router)
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"hostkey":"sample.com","data":{"default":"dynamic_ups","policies":[{"order":2,"policy":"modulo","mapper":{"type":"header","tag":"X-UID"},"routerTable":[{"result":"127.0.0.1:8888","expression":8},{"result":"127.0.0.1:7777","expression":7}]}]}}' \
        http://localhost:12345/router/add
    ```
    - 访问刚才添加的api server
    ```text
    curl -H 'content-type:application/json' -H 'Host:sample.com' -H 'X-UID:123458' http://localhost:8080
    ```
    - 返回内容，取不到X-UID时，请求将会在5555/6666的server之间进行轮询
    ```text
        this is the fake backend peer... listen port 8888
    ```
- 对主机名sample.com添加一条限流规则，取用户IP值作为限流key，限制每10秒钟内只能成功访问1次，其它限流规则参考[[Rate Limiting]](#ratelimiting)
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"hostkey":"sample.com","data":{"time_window":10,"rate":1,"type":"count","mapper":"ip"}}' \
        http://localhost:12345/rate/add
    ```
    - 访问刚才添加的api server
    ```text
    curl -H 'content-type:application/json' -H 'Host:sample.com' -H 'X-UID:123458' http://localhost:8080
    ```
    - 返回内容
    ```text
        this is the fake backend peer... listen port 8888
    ```
    - 被限流后返回
    ```json
    {
      "status": {
        "message": "Limited access,Service Temporarily Unavailable,please try again later :-)",
        "success": false
      },
      "code": 503
    }
    ```
- 对域名sample.com添加一条降级规则，并启动降级，所有的降级规则都是基于host+uri来进行的，当访问/test时返回执行降级策略，限流规则是优先于降级执行的，其它降级规则参考[[Service Degradation]](#servicedegradation)
    ```text
    curl -H 'content-type:application/json' -X POST --data \
        '{"hostkey":"sample.com","infos":[{"uri":"/test","info":{"type":"fake","enabled":true,"target":"This is a degraded fake data"}}]}' \
        http://localhost:12345/degrade/add
    ```
    - 访问刚才添加的api server
    ```text
    curl -H 'content-type:application/json' -H 'Host:sample.com' -H 'X-UID:123458' http://localhost:8080/test
    ```
    - 返回内容
    ```text
        {"message":"This is a degraded fake data"}
    ```
    - 再次访问将会进入上面添加的限流规则中

## 管理控制台API
- ### 枚举值
    - #### mapper 
        mapper是一组映射函数，会将请求映射到一个具体的值，以便将这个值交给policy进行运算,
        请求参数中如果有mapper字段只需要传递相应的枚举值即可，如"mapper":"ip"
        有一些mapper需要指定tag，此时mapper字段应传递一个json对象,如：{"type":"uri_args","tag":"uid"}，会取出请求参数中的uid的值
        
        | value              | Description                                               
        | ------------------:|:---------------------------------------------------------
        | `header`           | 取请求头中指定字段，配合tag字段使用，tag值表示请求头的名称       
        | `host`             | 取请求头/请求行中的host，无需指定tag                         
        | `ip`               | 取请求头中的用户ip，无需指定tag                           
        | `uri_args`         | 取请求中的uri参数，配合tag字段使用，tag值表示参数名称      
        | `uri`              | 取请求行中的uri                                          
        | `cookie`           | 取请求头中的cookie,配合tag字段使用，tag值表示cookie名称                                          
    - #### policy
        policy是一组计算函数，`string calculate(arg, hashTable)`，此函数接收一个具体值和一个规则对象，
        该对象中的数据结构应符合{"result":"xxx","expression":"xxxxxxxx"}的规则（组合规则除外），
        calculate函数会根据expression字段的表达式计算出一个boolean值，如果为true就立即返回result的值，否则就继续执行
    
        | value              | Description     |哈希表结构示例            
        | ------------------:|----------------:|:------------------------------
        | `modulo`           | 对10取模运算     |[{"result":"upstream1","expression":1},{"result":"upstream2","expression":2},{"result":"upstream3","expression":3}]
        | `range`            | 范围运算         |[{"result":"hehehehe","expression":[1001,2000]},{"result":"upstream1","expression":[min,"NONE"]},{"result":"upstream2","expression":[min,max]},{"result":"upstream3","expression":["NONE",max]}]                                   
        | `prefix`           | 取前缀匹配       |[{"result":"upstream1","expression":"/api"},{"result":"upstream2","expression":"/openApi"}]                          
        | `suffix`           | 取后缀匹配       |[{"result":"upstream1","expression":".js"},{"result":"upstream2","expression":".css"}]                       
        | `regex`            | lua正则匹配      |[{"result":"upstream1","expression":"regex1"},{"result":"upstream2","expression":"regex2"}]                         
        | `composite`        | 组合规则         |{"primary":{"order":2,mapper":"ip","policy":"range_policy","routerTable":[{"result":"secondary","expression":[1,100]},{"result":"upstream","expression":["NONE",1000]}]},"secondary":{"order":2,"mapper":"ip","policy":"range_policy","routerTable":[{"result":"secondary","expression":[1,100]}]}}
        | `unique`           | 返回唯一结果     |{"result":"upstream1"}         
- ### Router 
    - 动态路由，实现分流/灰度功能
    - 添加路由规则
        - 请求路径：/router/add
        - 请求方式：POST
        - 返回数据格式：JSON
        - 请求字段说明：
            - order：数字，多个规则排序，数值越大优先级越高
            - policy：枚举值，路由规则计算方式，对应枚举[policy](#policy)
            - routerTable：对象路由规则表，对应枚举[policy](#policy)中哈希表结构示例
            - mapper：枚举值，请求映射函数，对应枚举[mapper](#mapper)
            - tag：字符串，参考[mapper](#mapper)中对tag的说明
        - 请求数据示例：
            - 以下示例表示：从uri参数中提取uid的值，根据值的范围进行匹配，小于2000的将会被路由到upstream1，
        2001到3000之间的将被路由到upstream2，大于3000的将被路由到upstream3
            ```json
            {
              "hostkey": "www.sample.com",
              "data": {
                "default": "an upstream name",
                "policies": [{
                  "order": 3,
                  "policy": "range",
                  "mapper": {"type":"uri_args","tag":"uid"},
                  "routerTable": {
                    "upstream1": [
                      2000,
                      "NONE"
                    ],
                    "upstream2": [
                      2001,
                      3000
                    ],
                    "upstream3": [
                      "NONE",
                      3000
                    ]
                  }
                }]
              }
            }
            ```
    - 查询路由规则
        - 请求路径：/router/get
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
        - 返回数据格式：JSON
        - 返回数据示例：
            ```json
            {
              "status": {
                "message": "ok",
                "success": true
              },
              "code": 200,
              "data": {
                "policies": [
                  {
                    "order": 3,
                    "policy": "range",
                    "mapper": {"type":"uri_args","tag":"uid"},
                    "routerTable": {
                      "upstream4": [
                        1001,
                        2000
                      ]
                    }
                  },
                  {
                    "order": 2,
                    "policy": "range",
                    "mapper": "ip",
                    "routerTable": {
                      "upstream1": [
                        1001,
                        100
                      ]
                    }
                  }
                ],
                "default": "phi_upstream"
              }
            }
            ```
    - 查询所有路由规则
        - 请求路径：/router/getAll
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
        - 返回数据格式：JSON
    - 删除路由规则
        - 请求路径：/router/del
        - 请求方式：GET
        - 请求数据格式： uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
- ### DynamicUpstream
    - 动态的upstream列表，简单的负载均衡功能
    - 查询所有运行中的upstream信息
        - 请求路径：/upstream/getAllRuntimeInfo
        - 请求方式：GET
        - 返回数据格式：JSON
        - 返回数据示例：
            ```json
            {
                "status": {
                  "message": "ok",
                  "success": true
                },
                "code": 200,
                "data": {
                  "stable_ups": {
                    "primary": [
                      {
                        "weight": 1,
                        "id": 0,
                        "conns": 0,
                        "fails": 0,
                        "current_weight": 0,
                        "fail_timeout": 10,
                        "effective_weight": 1,
                        "name": "127.0.0.1:8888",
                        "max_fails": 1
                      }
                    ],
                    "backup": {}
                  },
                  "dynamic_ups": {
                    "127.0.0.1:12346": {
                      "weight": 100
                    },
                    "127.0.0.1:7777": {
                      "weight": 10
                    },
                    "127.0.0.1:8888": {
                      "weight": 10
                    },
                    "strategy": "resty_chash",
                    "mapper": "ip"
                  }
                }
            }
            ```
    - 查询所有upstream信息
        - 请求路径：/upstream/getAllUpsInfo
        - 请求方式：GET
        - 返回数据格式：JSON
        - 返回数据示例：
            ```json
            {
                "status": {
                  "message": "ok",
                  "success": true
                },
                "code": 200,
                "data": {
                  "stable_ups": {
                    "primary": [
                      {
                        "weight": 1,
                        "id": 0,
                        "conns": 0,
                        "fails": 0,
                        "current_weight": 0,
                        "fail_timeout": 10,
                        "effective_weight": 1,
                        "name": "127.0.0.1:8888",
                        "max_fails": 1
                      }
                    ],
                    "backup": {}
                  },
                  "dynamic_ups": {
                    "mapper": "ip",
                    "servers": [
                      {
                        "name": "127.0.0.1:8989",
                        "weight": 10
                      }
                    ],
                    "strategy": "resty_chash"
                  }
                }
            }
            ```
    - 查询指定upstream的server列表
        - 请求路径：/upstream/getUpstreamServers
        - 请求方式：GET/POST
        - 请求数据格式：uri参数/表单参数
        - 请求数据示例：
            ```text
                upstreamName=xxxx
            ``` 
        - 返回数据格式：JSON
        - 返回数据示例：
            ```json
            {
                "status": {
                  "message": "ok",
                  "success": true
                },
                "code": 200,
                "data": {
                  "127.0.0.1:12346": {
                    "weight": 100
                  },
                  "127.0.0.1:7777": {
                    "weight": 10
                  },
                  "127.0.0.1:8888": {
                    "weight": 10
                  },
                  "strategy": "resty_chash",
                  "mapper": "ip"
                }
            }
            ```
    - 从server列表中摘除/启动指定server，暂时不参与/重新参与负载均衡
        - 请求路径：/upstream/setPeerDown
        - 请求方式：GET/POST
        - 请求数据格式：uri参数/表单参数
        - 请求数据示例：
            ```text
            upstreamName=xxxx&serverName=xxx&down=true
            ```
    - 添加或者更新指定upstream
        - 请求路径：/upstream/addOrUpdateUps
        - 请求方式：POST
        - 请求数据格式：JSON
        - 字段说明：
            - mapper：请求映射函数，对应枚举[mapper](#mapper)
            - tag：参考[mapper](#mapper)中对tag的说明
            - strategy
                ###### LoadBalance
                枚举值，根据权重值分配负载均衡调用比例
            
                |value         |Description
                |-------------:|--------------------------:
                |resty_chash   |简单hash算法
                |roundrobin    |轮询算法
            - severs：数组，表示一组server，每一条记录有两个字段
                - name：表示server地址，ip:port
                - info：对象，目前支持2个字段
                    - weight：数字，表示该服务器的权重
                    - down：布尔型，表示是否参与负载均衡
        - 请求数据示例：
            ```json
            {
              "upstreamName": "a new upstream",
              "strategy": "resty_chash",
              "mapper": "ip",
              "servers": [
                {
                  "name": "127.0.0.1:8989",
                  "info": {
                    "weight": 10
                  }
                },
                {
                  "name": "127.0.0.1:8989",
                  "info": {
                    "weight": 10
                  }
                }
              ]
            }
            ```
    - 删除指定upstream
        - 请求路径：/upstream/delUps
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
                upstreamName=xxxx
            ```
    - 从指定upstream中删除servers
        - 请求路径：/upstream/delUpstreamServers
        - 请求方式：POST
        - 请求数据格式：JSON
        - 请求数据示例：
            ```json
            {
              "upstreamName": "a new upstream",
              "servers": [
                "127.0.0.1:8989"
              ]
            }
            ```
    - 向指定upstream中添加server,upstreamName不存在时会返回错误
        - 请求路径：/upstream/addUpstreamServers
        - 请求方式：POST
        - 请求数据格式：JSON
        - 请求数据示例：
            ```json
            {
                "upstreamName":"an exists upstream name",
                "servers":[{
                  "name":"127.0.0.1:8989",
                  "info":{
                      "weight":100
                  }
                }]
            }
            ```
- ### RateLimiting 
    - 动态路由，实现分流/灰度功能
    - 添加路由规则
        - 请求路径：/rate/add
        - 请求方式：POST
        - 返回数据格式：JSON
        - 请求字段说明
            - type：枚举值，多个规则排序，数值越大优先级越高
            
                |value      |Description       
                |----------:|:-----------------------------------------------
                |`req`      |限制请求速率，type=req时，需传递rate(速率)，burst(允许突发值)两个参数<br>例如：rate=200,burst=100，表示允许200req/sec，流量突发时最多允许达到300req/sec，其中超过200req的请求将被delay
                |`conn`     |限制并发连接数，type=conn时，需传递conn(连接数)，burst(允许突发连接数)，delay(延迟时间)三个参数<br>例如conn=100,burst=100,delay=0.05,表示正常允许100并发连接，突发流量下最大允许200并发连接，其中超出的部分，将被deplay
                |`count`    |限制单位时间窗口内的调用次数，type=count时，需传递rate(速率)，time_window(单位时间窗口)两个参数<br>例如rate=1000,time_window=60，表示60秒内最多允许调用1000次，超出的请求会被拒绝
                |`traffic`  |组合限流，启动组合限流时，组合限流需在请求数据中添加policies字段，数组类型[{"time_window": 10,"rate": 1,"}],每一条数据为一条限流规则，如需对多个规则进行排序，请在每一条中添加order字段，数字越大优先级越高
            - mapper：可选值，未传递此参数的情况下，所有限流粒度都是以host作为限流key，请求映射函数，对应枚举[mapper](#mapper)
            - tag：参考[mapper](#mapper)中对tag的说明
            - rejected：拒绝策略，rejected:直接拒绝访问，degrade:查询降级策略
        - 请求数据示例：
            ```json
            {
              "hostkey": "www.sample.com",
              "data": {
                "time_window": 10,
                "rejected": "xxx",
                "rate": 1,
                "type": "count"
              }
            }
            ```
    - 查询路由规则
        - 请求路径：/rate/get
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
        - 返回数据格式：JSON
    - 查询所有路由规则
        - 请求路径：/rate/getAll
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
        - 返回数据格式：JSON
    - 删除路由规则
        - 请求路径：/rate/del
        - 请求方式：GET
        - 请求数据格式： uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
- ### ServiceDegradation 
    - 接入层的简易降级开关，所有的降级都是以host+uri为依据
    - 添加降级数据
      - 请求路径：/degrade/add
      - 请求方式：POST
      - 返回数据格式：JSON
      - 请求字段说明
          - type：枚举值

            |value         |Description
            |-------------:|--------------------------:
            |`fake`   |返回target中指定的数据
            |`redirect`    |重定向到target指定的路径
          - "enabled": true/false，针对此uri的降级开关
      - 请求数据示例：
          ```json
          {
            "hostkey": "auto.deploy.com",
            "infos": [
              {
                "uri": "/uri",
                "info": {
                  "type": "redirect",
                  "enabled": true,
                  "target": "http://sample.com"
                }
              }
            ]
          }
          ```
    - 查询路由规则
        - 请求路径：/degrade/enabled
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx&uri=/xxxx
            ```
        - 返回数据格式：JSON
    - 查询路由规则
        - 请求路径：/degrade/get
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx
            ```
        - 返回数据格式：JSON
    - 查询所有路由规则
        - 请求路径：/degrade/getAll
        - 请求方式：GET
        - 请求数据格式：uri参数
        - 返回数据格式：JSON
    - 删除路由规则
        - 请求路径：/degrade/del
        - 请求方式：GET
        - 请求数据格式： uri参数
        - 请求数据示例：
            ```text
            hostkey=xxx&uri=/xxxx
            ```

## 性能测试
我在自己的笔记本上使用ab进行了简单的负载测试：
- 测试准备
    - nginx配置：开启一个worker进程，并且最多占用一个cpu核心
        ```nginx
        worker_processes 1;
        worker_cpu_affinity auto;
        ```
    - 开启另外一台nginx，作为一个静态文件服务器，目标文件大小为1Kb
    - 测试机器配置
        I7-6700HQ + 16GB
- 使用AB进行压力测试，20个并发，发起1000000次请求，使worker进程cpu达到100%
    - 我测试了原生的nginx反向代理进行对比：50K T/S
    - 开启router功能后测试结果：32K T/S
    - 开启dynamic ups和balancer之后： 25K T/S
    - 此测试应该可以反映，服务器在满负荷下的吞吐量极限值
    - 在开启多核情况下性能会有更高的提升，同时在多核心下以上三种场景的吞吐量差距会更小
- 测试在2000并发连接数下的系统稳定性：
   - TODO

## 使用的第三方lua库或工具
- [mobdebug] lua的远程调试工具
- [classic] 使用lua模拟面向对象编程
- [kong] kong的一些lua库
- [lua-resty-mlcache] lua的多级缓存工具，封装了lrucache和shared_dict的操作
- [lua-resty-worker-events] worker间异步通信
- [EmmyLua] IntelliJ idea的lua插件
- [ZeroBrane Studio] 轻量级的lua ide
- [MIO] resty的统计系统


[ZeroBrane Studio]:https://studio.zerobrane.com/support
[EmmyLua]:https://github.com/EmmyLua/IntelliJ-EmmyLua
[mobdebug]:https://studio.zerobrane.com/doc-remote-debugging
[classic]:https://github.com/rxi/classic
[kong]:https://konghq.com/
[lua-resty-mlcache]:https://github.com/thibaultcha/lua-resty-mlcache
[lua-resty-worker-events]:https://github.com/Kong/lua-resty-worker-events
[penlight]:https://github.com/stevedonovan/Penlight
[MIO]:https://github.com/iresty/Mio
[OpenResty]:https://openresty.org
[lua-nginx-module]:https://github.com/openresty/lua-nginx-module
[lua-upstream-nginx-module]:https://github.com/openresty/lua-upstream-nginx-module
