#!/bin/bash

DATADIR='<some_where>'

# Create an empty data dir
mkdir ${DATADIR}

# Fetch the full backup from master as an xb stream
# and extract it by piping to mbstream
ssh primary 'mariabackup --backup --stream=xbstream' | \
    mbstream -C ${DATADIR} -x

# Prepare the backup for import
mariabackup --prepare --target-dir=${DATADIR}
