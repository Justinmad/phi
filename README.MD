
## 启动管理控制台
```nginx
    
```
## 管理控制台API
- **枚举值**
    - ### mapper 
        mapper是一组映射函数，会将请求映射到一个具体的值，以便将这个值交给policy进行运算,
        有一些mapper需要指定tag，例如{"mapper":"header","tag":"x-uid"}，会取出请求头中的x-uid的值
        
        | value              | Description                                               
        | ------------------:|---------------------------------------------------------
        | `header`           | 取请求头中指定字段，配合tag字段使用，tag值表示请求头的名称       
        | `host`             | 取请求头/请求行中的host，无需指定tag                         
        | `ip`               | 取请求头中的用户ip，无需指定tag                           
        | `uri_args`         | 取请求中的uri参数，配合tag字段使用，tag值表示参数名称      
        | `uri`              | 取请求行中的uri                                          
    - ### policy
        policy是一组计算函数，`string calculate(arg, hashTable)`，此函数接收一个具体值和一个哈希表，
        经过运算后将结果与哈希表中的规则值进行匹配，匹配成功后会返回对应的哈希KEY值
    
        | value              | Description     |哈希表结构示例            
        | ------------------:|----------------:|------------------------------
        | `modulo`           | 对10取模运算|{"default":"stable_upstream","upstream_name_1":1,"upstream_name_2":2}
        | `range`            | 范围运算 |{"default":"stable_upstream","upstream_name_1":\[min,max],"upstream_name_2":\[min,"NONE"],"upstream_name_3":\["NONE",max]}                                    
        | `suffix`           | 取后缀匹配 |{"default":"stable_upstream","upstream_name_1":".html","upstream_name_2":".css"}                          
        | `composite`        | 组合规则 |{"default":"stable_upstream",<br>"primary":{"order":2,"tag":"ip","mapper":"ip","policy":"range_policy","routerTable":{"secondary":\[1,100],"upstream":\["NONE",1000]}},<br>"secondary":{"order":2,"mapper":"ip","policy":"range_policy","routerTable":{"upstream2":\[1,10]}}}
             
- **Router** : 动态路由，实现分流/灰度功能
    - 添加路由规则
        - 请求路径：/router/add
        - 请求方式：POST
        - 返回数据格式:JSON
        - 请求字段说明
            - order：number，多个规则排序，数值越大优先级越高
            - policy：路由规则计算方式，对应枚举[policy](#policy)
            - routerTable：路由规则表，对应枚举[policy](#policy)中哈希表结构示例
            - mapper：请求映射函数，对应枚举[mapper](#mapper)
            - tag：参考[mapper](#mapper)中对tag的说明
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
                  "tag": "uid",
                  "mapper": "uri_args",
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
- **Dynamic Upstream** : 动态的upstream列表，简单的负载均衡功能
    - 查询所有运行中的upstream信息
        - 请求路径：/upstream/getAllRuntimeInfo
        - 请求方式：GET
        - 返回数据格式:JSON
        - 返回数据示例:
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
                    "tag": "xxx",
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
        - 返回数据格式:JSON
        - 返回数据示例:
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
        - 请求数据示例:
            ```text
                upstreamName=xxxx
            ``` 
        - 返回数据格式:JSON
        - 返回数据示例:
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
                  "tag": "xxx",
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
        - 请求数据示例:
            ```text
            upstreamName=xxxx&serverName=xxx&down=true
            ```
    - 添加或者更新指定upstream
        - 请求路径：/upstream/addOrUpdateUps
        - 请求方式：POST
        - 请求数据格式：JSON
        - 枚举值：负载均衡策略 strategy：\[resty_chash|roundrobin]
        - 请求数据示例:
            ```json
            {
              "upstreamName": "a new upstream",
              "strategy": "resty_chash",
              "mapper": "mapper",
              "tag": "tag",
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
        - 请求数据示例:
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