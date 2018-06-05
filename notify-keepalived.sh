#!/bin/bash
TYPE=$1
NAME=$2
STATE=$3
case $STATE in
        "MASTER") /usr/sbin/service proxysql restart
                  ;;
        "BACKUP") /usr/sbin/service proxysql stop
                  ;;
        "FAULT")  /usr/sbin/service proxysql stop
                  exit 0
                  ;;
        *)        /sbin/logger "proxysql unknown state"
                  exit 1
                  ;;
esac
