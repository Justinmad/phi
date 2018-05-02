var instance = new Vue({
    el: '#app',
    data: {
        chart: {},
        node: {},
        menu: {
            phi: false,
            host: false,
            policy: false,
            upstream: false,
            server: false,
            ups_root: false,
            phi_upstream: false
        },
        chartLayout: "",
        x: 0,
        y: 0,
        newApiServerDialog: false,
        updatePolicyDialog: false,
        newUpstreamDialog: false,
        newServerDialog: false,
        limitTrafficDialog: false,
        newRateLimitingDialog: false,
        newDegradationDialog: false,
        newRouter: {
            hostkey: "",
            data: {
                "default": "",
                policies: []
            }
        },
        newUpstream: {
            upstreamName: "",
            strategy: "",
            mapper: "ip",
            servers: []
        },
        newServer: {
            name: '',
            info: {}
        },
        newRateLimiting: {},
        newDegradation: {info: {}},
        formRules: {
            string: [
                v => !!v || '非空字段，必须填写！',
                v => (typeof (v) === "string" || typeof (v) === "number") || '请填写正确的数据类型！'
            ],
            number: [
                v => !isNaN(Number(v)) || '请填写数字！',
                v => !!v || '非空字段，必须填写！',
            ],
            range: [
                v => !(isNaN(Number(v)) && v !== 'NONE') || '请填写数字或NONE！',
                v => !!v || '非空字段，必须填写！',
            ],
            ip: [
                v => !!v || '非空字段，必须填写！',
                v => /^(\d{1,3}\.){3}\d{1,3}\:\d{1,5}$/.test(v) || "ip:port格式必须正确"
            ],
            ups: [
                v => !!v || '非空字段，必须填写！',
                v => {
                    let b = /^(\d{1,3}\.){3}\d{1,3}\:\d{1,5}$/.test(v);
                    let c = (this.upstreams && this.upstreams.indexOf(v) !== -1) || (instance && instance.upstreams.indexOf(v) !== -1);
                    return b || c || "输入ip:port或选择已存在的upstream"
                }
            ]
        },
        limitTrafficTab: {
            tabActive: null,
            headers: {
                rateLimiting: [
                    {text: 'Limit Key', align: 'right', value: "mapper"},
                    {text: 'Type', align: 'right', value: "type"},
                    {text: 'Rejected', align: 'right', value: "rejected"},
                    {text: 'Uri', align: 'right', value: "uri"},
                    {text: 'Actions', align: 'center', sortable: false}
                ],
                degradation: [
                    {text: 'Uri', align: 'right', value: 'uri'},
                    {text: 'Type', align: 'right', value: "info.type"},
                    {text: 'Target', align: 'right', value: "info.target"},
                    {text: 'Status', align: 'center', value: "info.enabled"},
                    {text: 'Actions', align: 'center', sortable: false}
                ]
            },
            items: {
                rateLimiting: [],
                degradation: []
            },
        },
        formValid: false,
        formLoading: false,
        alertOption: {
            show: false,
            y: 'top',
            x: null,
            mode: 'multi-line',
            timeout: 2000,
            color: "success",
            message: "Hello, I'm a alert!"
        },
        confirmOption: {
            show: false,
            message: "确定要这样做吗？",
            color: null,
            callback: null
        },
        confirmFunc() {
            if (typeof (this.confirmOption.callback) === "function") {
                this.confirmOption.callback();
            }
            this.confirmOption.show = false;
        },
        mappers: [],
        policies: [],
        upstreams: [],
        balancers: [],
        limiters: ["req", "conn", "count"],
        rejectedStrategies: ["rejected", "degrade"],
        degradationStrategies: ["redirect", "fake"],
    },
    methods: {
        show(params) {
            let e = params.event.event;
            this.node = params.data;
            let menuType = this.node.type;
            if (typeof (this.menu[menuType]) === "boolean") {
                this.$nextTick(() => {
                    let keys = Object.keys(this.menu);
                    for (let i in keys) {
                        this.menu[keys[i]] = false;
                    }
                    this.menu[this.node.type] = true;
                    this.x = e.clientX;
                    this.y = e.clientY;
                })
            } else {
                alert("错误的节点类型:" + menuType);
            }
        },
        showTooltip(params) {
            let data = params.data;
            let type = data.type;
            if (type === "phi") {
                return "This is Phi Api Gateway !"
            } else if (type === "ups_root") {
                return "This is Upstream Root !"
            } else if (type === "host") {
                return "<table>" +
                    "<tr><td>Host:</td><td class='text-xs-right'>" + data.name + "</td></tr>" +
                    "<tr><td>Default:</td><td class='text-xs-right'>" + data.router.default + "</td></tr>" +
                    (data.router.policies ? "<tr><td>Routers:</td><td class='text-xs-right'>" + data.router.policies.length + "</td></tr>" : "") +
                    "</table>"
            } else if (type === "policy") {
                return "<table>" +
                    "<tr><td>Host:</td><td class='text-xs-right'>" + data.host + "</td></tr>" +
                    (data.stable ? "<tr><td>Default:</td><td class='text-xs-right'>" + data.name + "</td></tr>" : "") +
                    (data.stable ? "" : "<tr><td>Policy:</td><td class='text-xs-right'>" + data.policy + "</td></tr>") +
                    (data.stable ? "" : "<tr><td>Mapper:</td><td class='text-xs-right'>" + data.mapper + "</td></tr>") +
                    (data.tag ? "<tr><td>Tag:</td><td class='text-xs-right'>" + data.tag + "</td></tr>" : "") +
                    "</table>"
            } else if (type === "phi_upstream") {
                return "<table>" +
                    "<tr><td>Target:</td><td class='text-xs-right'>" + data.name + "</td></tr>" +
                    "<tr><td>Calculation:</td><td class='text-xs-right'>" + data.calculation + "</td></tr>" +
                    "<tr><td>Condition:</td><td class='text-xs-right'>" + data.condition + "</td></tr>" +
                    "</table>"
            } else if (type === "upstream") {
                return "<table>" +
                    "<tr><td>Editable:</td><td class='text-xs-right'>" + (!data.stable) + "</td></tr>" +
                    "<tr><td>Servers:</td><td class='text-xs-right'>" + data.children.length + "</td></tr>" +
                    (data.stable ? "" : "<tr><td>Load Balance:</td><td class='text-xs-right'>" + data.strategy + "</td></tr>") +
                    ((!data.stable && data.mapper) ? "<tr><td>Mapper:</td><td class='text-xs-right'>" + data.mapper + "</td></tr>" : "") +
                    ((!data.stable && data.tag) ? "<tr><td>Tag:</td><td class='text-xs-right'>" + data.tag + "</td></tr>" : "") +
                    "</table>"
            } else if (type === "server") {
                return "<table>" +
                    "<tr><td>Upstream:</td><td class='text-xs-right'>" + data.ups + "</td></tr>" +
                    "<tr><td>Server:</td><td class='text-xs-right'>" + data.name + "</td></tr>" +
                    "<tr><td>Weight:</td><td class='text-xs-right'>" + data.server.weight + "</td></tr>" +
                    "</table>"
            }
        },
        updateChart() {
            this.chart.showLoading();
            this.$http.get('/admin/tree').then(resp => {
                echarts.util.each(resp.body.data.children, function (datum, index) {
                    index % 2 === 0 && (datum.collapsed = true);
                });
                this.$http.get('/admin/upsTree').then(resp2 => {
                    this.chart.hideLoading();
                    this.chart.setOption({
                        series: [
                            {data: [resp.body.data]},
                            {data: [resp2.body.data]},
                        ]
                    });
                }, reason => {
                    this.alert("获取数据失败！", "error");
                })
            }, reason => {
                this.alert("获取数据失败！", "error");
            });
        },
        initRouterData() {
            this.newRouter = {
                hostkey: "",
                data: {
                    "default": "",
                    policies: []
                }
            }
        },
        updatePolicy() {
            this.newRouter = {
                hostkey: this.node.host || this.node.name,
                data: this.node.router
            };
            this.updatePolicyDialog = true;
        },
        updateUpstream() {
            let keys = Object.keys(this.node.upstream);
            this.newUpstream.upstreamName = this.node.name;
            this.newUpstream.strategy = this.node.upstream.strategy;
            this.newUpstream.mapper = this.node.upstream.mapper;
            for (let i in this.node.upstream.servers) {
                let s = this.node.upstream.servers[i];
                this.newUpstream.servers.push({
                    name: s.name,
                    info: {
                        weight: s.weight
                    }
                });
            }
            this.newUpstreamDialog = true;
        },
        newRouterApi() {
            let valided;
            if (!this.newRouter.data.policies || this.newRouter.data.policies.length <= 0)
                valided = this.$refs.routerForm.validate();
            if (this.newRouter.data.policies && this.newRouter.data.policies.length > 0)
                valided = this.$refs.policyForm.validate();
            if (valided) {
                this.formLoading = true;
                this.$http.post("/router/add", this.newRouter
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.newApiServerDialog = false;
                        this.updatePolicyDialog = false;
                        this.updateChart();
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                    this.formLoading = false;
                }, reason => {
                    this.alert(reason.bodyText, "error");
                })
            } else {
                this.alert("请检查表单项是否完整？", "warning");
            }
        },
        newUpstreamApi() {
            let valided = this.$refs.upstreamForm.validate();
            if (valided) {
                this.formLoading = true;
                this.$http.post("/upstream/addOrUpdateUps", this.newUpstream
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.newUpstreamDialog = false;
                        this.updateChart();
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                    this.formLoading = false;
                    this.getUpstreamsApi();
                }, reason => {
                    this.alert(reason.bodyText, "error");
                })
            } else {
                this.alert("请检查表单项是否完整？", "warning");
            }
        },
        newRateLimitingApi() {
            let valided = this.$refs.rateForm.validate();
            if (valided) {
                this.formLoading = true;
                let params = {
                    hostkey: this.node.name,
                    data: this.newRateLimiting
                };
                if (this.limitTrafficTab.items.rateLimiting.length > 0 && !(this.limitTrafficTab.items.rateLimiting.length === 1 && this.newRateLimiting.edit)) {
                    let data = this.limitTrafficTab.items.rateLimiting.concat();
                    // new item
                    if (!this.newRateLimiting.edit) {
                        data.push(this.newRateLimiting);
                    } else {
                        data[this.newRateLimiting.index] = this.newRateLimiting;
                    }
                    // traffic
                    params.data = {
                        type: "traffic",
                        policies: data
                    }
                }
                this.newRateLimiting.edit = undefined;
                this.newRateLimiting.index = undefined;
                this.$http.post("/rate/add", params
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.getLimitTrafficApi(this.node.name);
                        this.newRateLimitingDialog = false;
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                    this.formLoading = false;
                }, reason => {
                    this.alert(reason.bodyText, "error");
                })
            } else {
                this.alert("请检查表单项是否完整？", "warning");
            }
        },
        delRateLimitingApi(index) {
            this.confirm(() => {
                this.limitTrafficTab.items.rateLimiting.splice(index, 1);
                if (this.limitTrafficTab.items.rateLimiting.length === 0) {
                    this.$http.get("/rate/del?hostkey=" + this.node.name).then(resp => {
                        if (resp.body.status.success) {
                            this.alert(resp.body.status.message || "ok", "success");
                        } else {
                            this.alert(resp.body.status.message, "warning");
                        }
                    }, reason => {
                        this.alert(reason.bodyText, "error");
                    });
                } else {
                    let params = {
                        hostkey: this.node.name,
                        data: {
                            type: "traffic",
                            policies: this.limitTrafficTab.items.rateLimiting
                        }
                    };
                    if (this.limitTrafficTab.items.rateLimiting.length === 1) {
                        params = {
                            hostkey: this.node.name,
                            data: this.limitTrafficTab.items.rateLimiting[0]
                        };
                    }
                    this.$http.post("/rate/add", params
                    ).then(resp => {
                        if (resp.body.status.success) {
                            this.alert(resp.body.status.message || "ok", "success");
                            this.getLimitTrafficApi(this.node.name);
                            this.newRateLimitingDialog = false;
                        } else {
                            this.alert(resp.body.status.message, "warning");
                        }
                        this.formLoading = false;
                    }, reason => {
                        this.alert(reason.bodyText, "error");
                    })
                }
                this.getLimitTrafficApi(this.node.name);
            })
        },
        newDegradationApi() {
            let valided = this.$refs.degradationForm.validate();
            if (valided) {
                this.$http.post("/degrade/add", {
                        hostkey: this.node.name,
                        infos: [this.newDegradation]
                    }
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.getLimitTrafficApi(this.node.name);
                        this.newDegradationDialog = false;
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                    this.formLoading = false;
                }, reason => {
                    this.alert(reason.bodyText, "error");
                })
            } else {
                this.alert("请检查表单项是否完整？", "warning");
            }
        },
        delDegradationApi(hostkey, uri, index) {
            this.confirm(() => {
                this.$http.get("/degrade/del?hostkey=" + hostkey + "&uri=" + uri).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.limitTrafficTab.items.degradation.splice(index, 1)
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            });
        },
        enabledDegradationApi(hostkey, uri, enabled) {
            this.confirm(() => {
                this.$http.get("/degrade/enabled?hostkey=" + hostkey + "&uri=" + uri + "&enabled=" + enabled).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.getLimitTrafficApi(hostkey);
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            });
        },
        delRouterApi(hostkey) {
            this.confirm(() => {
                this.$http.get("/router/del?hostkey=" + hostkey).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        // this.updateChart();
                        window.location = "/"
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            })
        },
        delUpstreamApi(ups) {
            this.confirm(() => {
                this.$http.get("/upstream/delUps?upstreamName=" + ups).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        // this.updateChart();
                        window.location = "/"
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            })
        },
        addServerToUpsApi(ups) {
            let valided = this.$refs.serverForm.validate();
            if (valided) {
                this.formLoading = true;
                this.$http.post("/upstream/addUpstreamServers", {
                        upstreamName: ups,
                        servers: [this.newServer]
                    }
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.newServerDialog = false;
                        this.updateChart();
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                    this.formLoading = false;
                }, reason => {
                    this.alert(reason.bodyText, "error");
                })
            } else {
                this.alert("请检查表单项是否完整？", "warning");
            }
        },
        deleteServerFromUpsApi(ups) {
            this.confirm(() => {
                this.$http.post("/upstream/delUpstreamServers", {
                    upstreamName: ups,
                    servers: [this.node.name]
                }).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        // this.updateChart();
                        window.location = "/"
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            })
        },
        setPeerDown(ups) {
            this.confirm(() => {
                this.$http.get("/upstream/setPeerDown", {
                    params: {
                        upstreamName: ups,
                        serverName: this.node.name,
                        down: !this.node.down
                    }
                }).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.updateChart();
                    } else {
                        this.alert(resp.body.status.message, "warning");
                    }
                }, reason => {
                    this.alert(reason.bodyText, "error");
                });
            })
        },
        alert(msg, color) {
            if (typeof (msg) === "object") {
                this.alertOption = msg;
                this.alertOption.show = true;
            } else {
                if (msg) this.alertOption.message = msg;
                if (color) this.alertOption.color = color;
                this.alertOption.show = true;
            }
        },
        confirm(callback, message, color) {
            if (message) this.confirmOption.message = message;
            if (callback) this.confirmOption.callback = callback;
            if (color) this.confirmOption.color = color;
            this.confirmOption.show = true;
        },
        getPoliciesApi() {
            this.$http.get("/admin/policies").then(resp => {
                if (resp.body.status.success) {
                    this.policies = resp.body.data
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
        },
        getMappersApi() {
            this.$http.get("/admin/mappers").then(resp => {
                if (resp.body.status.success) {
                    this.mappers = resp.body.data
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
        },
        getUpstreamsApi() {
            this.$http.get("/upstream/getAllUpsInfo").then(resp => {
                if (resp.body.status.success) {
                    this.upstreams = Object.keys(resp.body.data)
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
        },
        getLoadBalanceStrategyApi() {
            this.$http.get("/admin/balancers").then(resp => {
                if (resp.body.status.success) {
                    this.balancers = resp.body.data
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
        },
        getLimitTrafficApi(hostkey) {
            this.$http.get("/rate/get?hostkey=" + hostkey).then(resp => {
                if (resp.body.status.success) {
                    let items = resp.body.data;
                    if (items) {
                        if (items.type === "traffic") {
                            this.limitTrafficTab.items.rateLimiting = items.policies
                        } else {
                            this.limitTrafficTab.items.rateLimiting = [items]
                        }
                    }
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
            this.$http.get("/degrade/get?hostkey=" + hostkey).then(resp => {
                if (resp.body.status.success) {
                    this.limitTrafficTab.items.degradation = resp.body.data;
                } else {
                    this.alert(resp.body.status.message, "warning");
                }
            }, reason => {
                this.alert(reason.bodyText, "error");
            });
        },
        addPolicy() {
            if (!this.newRouter.data.policies) {
                this.newRouter.data.policies = []

            }
            this.newRouter.data.policies.push({order: 0, mapper: '', policy: '', routerTable: []})
        },
        mappedKey(mapper) {
            if (typeof (mapper) === "string") {
                return mapper
            } else if (mapper.length > 0) {
                let tmp = [];
                mapper.forEach(function (element) {
                    tmp.push(this.mappedKey(element))
                });
                return tmp.concat(":")
            } else {
                return mapper.type + (mapper.tag && (":" + mapper.tag))
            }
        },
        formatJson(jsonStr) {
            try {
                return JSON.stringify(JSON.parse(jsonStr), null, 4)
            } catch (e) {
                return jsonStr
            }
        }
    },
    mounted: function () {
        let elementById = document.getElementById('main');
        elementById.oncontextmenu = function () {
            return false;
        };
        elementById.style.height = window.innerHeight - 36 - 48 + "px";
        let myChart = echarts.init(elementById);
        myChart.showLoading();
        this.$http.get('/admin/tree').then(resp => {
            let tree1 = resp.body.data;
            this.$http.get('/admin/upsTree').then(function (resp2) {
                let tree2 = resp2.body.data;
                myChart.hideLoading();
                echarts.util.each(resp.body.data.children, function (datum, index) {
                    index % 2 === 0 && (datum.collapsed = true);
                });
                myChart.setOption({
                    tooltip: {
                        trigger: 'item',
                        triggerOn: 'mousemove',
                        formatter: (params, ticket, callback) => {
                            return this.showTooltip(params);
                        }
                    },
                    legend: {
                        top: '2%',
                        left: '3%',
                        orient: 'vertical',
                        data: [
                            {
                                name: 'Phi',
                                icon: 'rectangle'
                            },
                            {
                                name: 'Upstreams',
                                icon: 'rectangle'
                            }
                        ],
                        borderColor: '#c23531'
                    },
                    series: [
                        {
                            type: 'tree',
                            name: 'Phi',
                            top: '5%',
                            left: '5%',
                            bottom: '5%',
                            right: '60%',
                            data: [tree1],
                            symbolSize: 25,
                            label: {
                                normal: {
                                    position: 'left',
                                    verticalAlign: 'middle',
                                    align: 'right',
                                    fontSize: 10
                                }
                            },
                            itemStyle: {
                                borderColor: "green"
                            },
                            expandAndCollapse: true,
                            animationDuration: 550,
                            animationDurationUpdate: 750,
                            initialTreeDepth: -1
                        },
                        {
                            type: 'tree',
                            name: 'Upstreams',
                            top: '20%',
                            left: '60%',
                            bottom: '20%',
                            right: '5%',
                            data: [tree2],
                            symbolSize: 25,
                            label: {
                                normal: {
                                    position: 'left',
                                    verticalAlign: 'middle',
                                    align: 'right',
                                    fontSize: 10
                                }
                            },
                            itemStyle: {
                                borderColor: "green"
                            },
                            expandAndCollapse: true,
                            animationDuration: 550,
                            animationDurationUpdate: 750,
                            initialTreeDepth: -1
                        }
                    ]
                });
            }, reason => {
                this.alert("获取数据失败！", "error");
            });
        }, reason => {
            this.alert("获取数据失败！", "error");
        });
        myChart.on("contextmenu", (params) => {
            this.show(params);
        });
        this.chart = myChart;
        this.getMappersApi();
        this.getPoliciesApi();
        this.getUpstreamsApi();
        this.getLoadBalanceStrategyApi();
    },
    watch: {
        chartLayout: function (newVal) {
            let option = {
                series: [
                    {
                        layout: newVal
                    },
                    {
                        layout: newVal
                    }
                ]
            };
            if (newVal === "orthogonal") {
                let label = {
                    normal: {
                        position: 'left',
                        verticalAlign: 'middle',
                        align: 'right',
                        fontSize: 10
                    }
                };
                option.series[0].label = label;
                option.series[1].label = label;
            } else {
                option.series[0].label = {};
                option.series[1].label = {};
            }
            this.chart.setOption(option);
        },
        newApiServerDialog: function (newVal) {
            if (newVal === false) {
                this.initRouterData();
            }
        },
        updatePolicyDialog: function (newVal) {
            if (newVal === false) {
                this.initRouterData();
            }
        },
        limitTrafficDialog: function (newVal) {
            if (newVal === false) {
                this.limitTrafficTab.items.degradation = [];
                this.limitTrafficTab.items.rateLimiting = [];
            } else {
                this.getLimitTrafficApi(this.node.name);
            }
        },
        newRateLimitingDialog: function (newVal) {
            if (newVal === false) {
                this.newRateLimiting = {};
            } else {
                this.getLimitTrafficApi(this.node.name);
            }
        },
        newDegradationDialog: function (newVal) {
            if (newVal === false) {
                this.newDegradation = {info: {}};
            }
        },
        newUpstreamDialog: function (newVal) {
            if (newVal === false) {
                this.newUpstream = {
                    upstreamName: "",
                    strategy: "",
                    mapper: "ip",
                    servers: []
                }
            }
        },
        "confirm.show": function (newVal) {
            if (newVal === false) {
                this.confirmOption = {
                    show: false,
                    message: "确定要这样做吗？",
                    color: "success",
                    callback: null
                }
            }
        },
        "alert.show": function (newVal) {
            if (newVal === false) {
                this.alertOption = {
                    show: false,
                    y: 'top',
                    x: null,
                    mode: '',
                    timeout: 2000,
                    color: "",
                    message: "Hello, I'm a alert!"
                }
            }
        }
    }
});