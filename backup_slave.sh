#!/bin/bash
# vars
monitoring="<zabix_IP>"
trap "zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 1 > /dev/null 2>&1" ERR
backuppath="<backup_dst_fullpath>"
dbuser="root"
dbpass="root@localhost pass"
TMPFILE="<logging_tempfile_fullpath>"
RET=8 # remove backups older than $RET days
mkdir -p ${backuppath}
# checks
MasterIP="$(echo "show slave status\G" | mysql | grep "Master_Host:" | awk '{print $2}')"
MasterPort="$(echo "show slave status\G" | mysql | grep "Master_Port:" | awk '{print $2}')"
SlaveIO="$(echo "show slave status\G" | mysql | grep "Slave_IO_Running:" | awk '{print $2}')"
SlaveSQL="$(echo "show slave status\G" | mysql | grep "Slave_SQL_Running:" | awk '{print $2}')"
declare -i SlaveBehind=$(echo "show slave status\G" | mysql | grep "Seconds_Behind_Master:" | awk '{print $2}');
# run backup
if [[ ( "${SlaveIO}" = "Yes" && "${SlaveSQL}" = "Yes" && "${SlaveBehind}" -le 300 ) ]]
# if slave ok, take local backup and reset alert on monitoring
	then
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveLagAlert -o 0 > /dev/null 2>&1
	  bash -c "innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ | gzip -c | cat > ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.tar.gz" 2>"${TMPFILE}"
	  result="$(grep -o " completed OK" ${TMPFILE})";
	  mv ${TMPFILE} ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.log
# if slave Nok, take backup from the master and raise alert on monitoring
	else
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveLagAlert -o 1 > /dev/null 2>&1
	  ssh root@${MasterIP} "innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ | gzip -c | cat" > ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.tar.gz 2>"${TMPFILE}"
	  result="$(grep -o " completed OK" ${TMPFILE})";
          mv ${TMPFILE} ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.log
fi
# send backup result to monitoring
if [[ "${result}" = " completed OK" ]]
	then
# if last backup OK, remove older backups
	  find ${backuppath}/ -type f -name "bck_*" -mtime +${RET} -delete > /dev/null 2>&1
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 0 > /dev/null 2>&1
	  exit 0
	else
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 1 > /dev/null 2>&1
	  exit 1
fi
