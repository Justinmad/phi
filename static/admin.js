new Vue({
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
        newRouter: {
            hostkey: "",
            data: {
                "default": "",
                policies: []
            }
        },
        formRules: {
            string: [
                v => !!v || '非空字段，必须填写！'
            ],
            number: [
                v => !isNaN(Number(v)) || '请填写数字！',
                v => !!v || '非空字段，必须填写！',
            ]
        },
        formValid: false,
        formLoading: false,
        alertOption: {
            show: false,
            y: 'top',
            x: null,
            mode: '',
            timeout: 2000,
            color: "success",
            message: "Hello, I'm a alert!"
        },
        confirmOption: {
            show: false,
            message: "Are you sure you want to do this?",
            color: "success",
            callback: null
        },
        confirmFunc() {
            if (typeof (this.confirmOption.callback) === "function") {
                this.confirmOption.callback();
            }
            this.confirmOption.show = false;
        }
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
        newRouterApi() {
            if (this.$refs.routerForm.validate()) {
                this.formLoading = true;
                this.$http.post("/router/add", this.newRouter
                ).then(resp => {
                    if (resp.body.status.success) {
                        this.alert(resp.body.status.message || "ok", "success");
                        this.newApiServerDialog = false;
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
        alert(msg, color) {
            if (typeof (msg) === "object") {
                this.alertOption = msg;
                this.alertOption.show = true;
            } else {
                this.alertOption.message = msg;
                this.alertOption.color = color;
                this.alertOption.show = true;
            }
        },
        confirm(callback, message, color) {
            this.confirmOption = {
                show: true,
                message,
                color,
                callback: callback
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
            alert("获取数据失败！");
        });
        myChart.on("contextmenu", (params) => {
            console.log(params);
            this.show(params);
        });
        this.chart = myChart
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
                    color: "success",
                    message: "Hello, I'm a alert!"
                }
            }
        }
    }
});