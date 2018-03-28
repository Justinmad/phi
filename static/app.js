new Vue({
    el: '#app',
    data: {
        status: 'Hello Vue!'
    },
    methods: {
        getStatus: function () {
            this.$http.get('/api/status').then(function (response) {
                this.status = response.body;
            }, function (response) {
            });
        }
    },
    mounted: function () {
        this.getStatus()
    }
});