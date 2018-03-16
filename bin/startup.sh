#!/usr/bin/env bash
PREFIX = `pwd`/../conf
ps -ef|grep "nginx -c nginx-test.conf -p /home/tengine/conf"|grep -v grep|awk '{print $2}'|xargs kill
sleep 5
mkdir -p ${PREFIX}/logs
nginx -c main.conf -p ${PREFIX}