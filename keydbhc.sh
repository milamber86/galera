#!/bin/bash
host="${1}";
port="${2}";
pass="keydbpass";
clitimeout=5;
test="$(echo -e "info replication\nQUIT\n" | timeout -k ${clitimeout} ${clitimeout} keydb-cli -h ${host} -p ${port} -a ${pass} 2>/dev/null | grep ^role | awk -F':' '{print $2}')";
if [[ "$test" =~ "active-replica" ]]
  then
    exit 0
  else
    exit 1
fi
