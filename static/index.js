new Vue({
    el: '#app',
    data: {
        mioDisabled: false,
        status: {
            connections: {},
            requests: {},
            total: {},
            upstreams: {}
        }
    },
    methods: {
        initData: function () {
            this.$http.get('status').then(function (resp) {
                if (resp.body.mio_disabled) {
                    this.mioDisabled = true;
                    return
                }
                this.status = resp.body;
            }, function (reason) {
                console.log(reason);
                alert("获取status失败！");
            })
        }
    }, computed: {
        upsServers: function () {
            let all = 0;
            let up = [];
            let down = [];
            let alerts = [];
            let ups = this.status.upstreams;
            if (ups) {
                let keys = Object.keys(ups);
                for (let i = 0; i < keys.length; i++) {
                    let peers = ups[keys[i]].peers;
                    all += peers.length;
                    for (let j = 0; j < peers.length; j++) {
                        let peer = peers[j];
                        if (peer.down) {
                            down.push(peer)
                        } else {
                            up.push(peer)
                        }
                        if (peer.fails > peer.requests || (peer.requests > 0 && peer.fails / peer.requests > 0.01)) {
                            alerts.push(peer)
                        }
                    }
                }
            }
            return {
                all: all,
                up: up,
                down: down,
                alerts: alerts
            }
        },
        serverZone: function () {
            let problems = [];
            let trafficIn = 0;
            let trafficOut = 0;
            let total = 0;
            let server_zones = this.status.server_zones;
            if (server_zones) {
                let keys = Object.keys(server_zones);
                total = keys.length;
                for (let i in keys) {
                    let zone = server_zones[keys[i]];
                    trafficIn += zone.receive_per_second;
                    trafficOut += zone.send_per_second;
                    if (zone.responses.total > 1000 && (zone.responses["5xx"] / zone.responses.total > 0.05)) {
                        problems.push(zone)
                    }
                }
            }
            return {
                total: total,
                problems: problems,
                trafficIn: (trafficIn / 1024).toFixed(2),
                trafficOut: (trafficOut / 1024).toFixed(2)
            }
        }
    }, mounted: function () {
        setInterval(() => {
            this.initData()
        }, 1000);
    }, watch: {}
});