new Vue({
    el: '#app',
    data: {},
    methods: {},
    mounted: function () {
        let elementById = document.getElementById('main');
        elementById.style.height = window.innerHeight - 36 - 48 + "px";
        let myChart = echarts.init(elementById);
        myChart.showLoading();
        this.$http.get('/admin/tree').then(function (resp) {
            myChart.hideLoading();
            echarts.util.each(resp.body.data.children, function (datum, index) {
                index % 2 === 0 && (datum.collapsed = true);
            });
            myChart.setOption(option = {
                tooltip: {
                    trigger: 'item',
                    triggerOn: 'mousemove'
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

                        expandAndCollapse: true,
                        animationDuration: 550,
                        animationDurationUpdate: 750
                    }
                ]
            });
        }, function (reason) {
            console.log(reason);
            alert("获取数据失败！");
        });
    }
});