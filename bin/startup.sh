#!/usr/bin/env bash
mkdir `pwd`/../conf/logs
nginx -c main.conf -p `pwd`/../conf