#!/usr/bin/env bash
PREFIX=`pwd`/../conf
ngx_master_pid=`ps -ef|grep "nginx -c main.conf -p ${PREFIX}"|grep -v grep|awk '{print $2}'`
if [ -n ${ngx_master_pid} ]; then
    kill ${ngx_master_pid}
    echo "wait 5 sec to kill nginx master process"
    sleep 5
fi
mkdir -p ${PREFIX}/logs
nginx -c main.conf -p ${PREFIX}