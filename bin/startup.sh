#!/usr/bin/env bash
PREFIX=`pwd`/../conf
ps -ef|grep "nginx -c main.conf -p ${PREFIX}"|grep -v grep|awk '{print $2}'|xargs kill
sleep 5
echo "wait 5 sec to kill nginx master process"
mkdir -p ${PREFIX}/logs
nginx -c main.conf -p ${PREFIX}