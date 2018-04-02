var instance = new Vue({
    el: '#app',
    data: {
        chart: {},
        items: [
            {title: 'Click Me'},
            {title: 'Click Me'},
            {title: 'Click Me'},
            {title: 'Click Me 2'}
        ],
        node: {},
        menu: {
            phi: false,
            host: false,
            policy: false,
            upstream: false,
            server: false,
        },
        chartLayout: "",
        x: 0,
        y: 0,
        newApiServerDialog: false,
        updatePolicyDialog: false,
        newUpstreamDialog: false,
        newServerDialog: false,
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
        formRules: {
            string: [
                v => !!v || '非空字段，必须填写！',
                v => (typeof (v) === "string" || typeof (v) === "number") || '请填写正确的数据类型！'
            ],
            number: [
                v => !isNaN(Number(v)) || '请填写数字！',
                v => !!v || '非空字段，必须填写！',
            ],
            ip: [
                v => !!v || '非空字段，必须填写！',
                v => /^(\d{1,3}\.){3}\d{1,3}\:\d{1,5}$/.test(v) || "ip:port格式必须正确"
            ],
            ups: [
                v => !!v || '非空字段，必须填写！',
                v => (/^(\d{1,3}\.){3}\d{1,3}\:\d{1,5}$/.test(v) || instance.upstreams.indexOf(v) !== -1) || "输入ip:port或选择存在的upstream"
            ]
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
            message: "Are you sure you want to do this?",
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
        balancers: []
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
        updateChart() {
            this.chart.showLoading();
            this.$http.get('/admin/tree').then(resp => {
                this.chart.hideLoading();
                // echarts.util.each(resp.body.data.children, function (datum, index) {
                //     index % 2 === 0 && (datum.collapsed = true);
                // });
                this.chart.setOption({
                    series: [
                        {
                            data: [resp.body.data]
                        }]
                });
            }, function (reason) {
                console.log(reason);
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
        updateRouter() {
            this.newRouter = {
                hostkey: this.node.name,
                data: this.node.router
            };
            this.newApiServerDialog = true;
        },
        updatePolicy() {
            this.newRouter = {
                hostkey: this.node.host || this.node.name,
                data: this.node.router
            };
            this.updatePolicyDialog = true;
        },
        updateUpstream() {
            console.log(this.node)
            let keys = Object.keys(this.node.upstream);
            this.newUpstream.upstreamName = this.node.name;
            for (let i in keys) {
                let k = keys[i];
                if (k === "strategy" || k === "mapper") {
                    this.newUpstream[k] = this.node.upstream[k]
                } else {
                    this.newUpstream.servers.push({
                        name: k,
                        info: this.node.upstream[k]
                    });
                }
            }
            this.newUpstreamDialog = true;
        },
        newRouterApi() {
            let valided;
            if (this.newRouter.data.policies.length <= 0)
                valided = this.$refs.routerForm.validate();
            if (this.newRouter.data.policies.length > 0)
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
        delRouterApi(hostkey) {
            this.confirm(() => {
                this.$http.get("/router/del?hostkey=" + hostkey).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        window.location = "/"
                        // this.updateChart()
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
                        // window.location = "/"
                        this.updateChart()
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
    },
    mounted: function () {
        let elementById = document.getElementById('main');
        elementById.oncontextmenu = function () {
            return false;
        };
        elementById.style.height = window.innerHeight - 36 - 48 + "px";
        let myChart = echarts.init(elementById);
        myChart.showLoading();
        this.$http.get('/admin/tree').then(function (resp) {
            myChart.hideLoading();
            // echarts.util.each(resp.body.data.children, function (datum, index) {
            //     index % 2 === 0 && (datum.collapsed = true);
            // });
            myChart.setOption({
                tooltip: {
                    trigger: 'item',
                    triggerOn: 'mousemove',
                    formatter: function (params, ticket, callback) {
                        return "Loading";
                    }
                },
                series: [
                    {
                        type: 'tree',
                        data: [resp.body.data],
                        symbolSize: 10,
                        label: {
                            normal: {
                                position: 'left',
                                verticalAlign: 'middle',
                                align: 'right',
                                fontSize: 10
                            }
                        },
                        leaves: {
                            label: {
                                normal: {
                                    position: 'right',
                                    verticalAlign: 'middle',
                                    align: 'left'
                                }
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
        }, function (reason) {
            console.log(reason);
            this.alert("获取数据失败！", "error");
        });
        myChart.on("contextmenu", (params) => {
            console.log(params);
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
            this.chart.setOption({
                series: [
                    {
                        layout: newVal
                    }]
            });
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
                    message: "Are you sure you want to do this?",
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