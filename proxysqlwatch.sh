#!/bin/bash
proxysql_user="admin";
proxysql_pass="admin"
echo -en "HOSTGROUPS -- 2: writer | 3: reader | 4: backup writer | 1: offline\n\n"
mysql -h 127.0.0.1 -P 6032 -u"${proxysql_user}" -p"${proxysql_pass}" -t \
        -e "select 'WRITER HOSTGROUP:' AS '';" \
        -e "select * from stats_mysql_connection_pool where hostgroup = 2 order by srv_host;" \
        -e "select 'READER HOSTGROUP:' AS '';" \
        -e "select * from   stats_mysql_connection_pool where hostgroup = 3 order by srv_host;" \
        -e "select '1:OFFLINE, 4:BACKUP WRITER HOSTGROUP:' AS '';" \
        -e "select * from stats_mysql_connection_pool where hostgroup in (4,1) order by hostgroup,srv_host;" \
        -e "select 'CONFIGURED MySQL SERVERS:' AS '';" \
        -e "select hostgroup_id,hostname,status,weight,comment from mysql_servers where hostgroup_id in (2,3,4,1) order by hostgroup_id,hostname;" \
        -e "select 'LATENCY, ERROR:' AS '';" \
        -e "SELECT * FROM  monitor.mysql_server_connect_log ORDER BY hostname,time_start_us DESC LIMIT 10;" \
        -e "select 'STATUS, CONNECTIONS:' AS '';" \
        -e "select hostgroup,srv_host,status,ConnUsed,MaxConnUsed,Queries,Latency_us from stats.stats_mysql_connection_pool order by hostgroup,srv_host;" \
        -e "select 'GALERA HEALTH:' AS '';" \
        -e "select * from mysql_server_galera_log order by time_start_us desc limit 3\G"
exit 0
