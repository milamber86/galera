#!/bin/bash
# run on master node: keydbinstall.sh "<IP node 1>" "<IP node 2>" "<IP keepalived VIP>" "<interface name, ie: eth0 or ens192>" "<keepalived vrrp instance priority>"
# set keepalived priority 100 for master node, set keepalived priotity 98 and swap unicast peers for slave node
# - vrrp and keydb passwords are generated, you can find them in /etc/keepalived/keepalived.conf and /etc/keydb/keydb.conf after installation
# - KeyDB should be accessible on VIP 192.168.1.100:9736 after installation
# - firewall is not configured by this script
# - keepalived snmp monitoring socket is configured to listen on 127.0.0.1:700
# example:
# master node: 192.168.1.101
# slave node:  192.168.1.102
# VIP IP:      192.168.1.100
# vrrp interface name: ens192
# ./keydbinstall.sh "192.168.1.101" "192.168.1.102" "192.168.1.100" "ens192" "100" #(run on master node)
# ./keydbinstall.sh "192.168.1.102" "192.168.1.101" "192.168.1.100" "ens192" "98" #(run on slave node)
#
IPnode1="${1}";
IPnode2="${2}";
IPVIP="${3}";
VIPifname="${4}";
priority="${5}"
keydbPass="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w12 | head -n1)";
keepalivedPass="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w12 | head -n1)";

### keydb
yum -y update
yum -y install vim rsync
rpm --import https://download.keydb.dev/packages/rpm/RPM-GPG-KEY-keydb
yum -y install https://download.keydb.dev/packages/rpm/centos7/x86_64/keydb-latest-1.el7.x86_64.rpm
mkdir -p /var/log/keydb
cp -v /etc/keydb/keydb.conf /etc/keydb/keydb.conf_bak
cat > /etc/keydb/keydb.conf << EOF
bind 0.0.0.0
port 6379
requirepass ${keydbPass}
masterauth ${keydbPass}
multi-master yes
active-replica yes
replica-read-only no
replicaof ${IPnode2} 6379
dbfilename dump.rdb
dir /var/lib/keydb/
daemonize yes
pidfile /var/run/keydb/keydb-server.pid
loglevel notice
logfile /var/log/keydb/keydb.log
EOF

systemctl enable keydb
systemctl start keydb
systemctl status keydb

### keepalived
groupadd -r keepalived_script
useradd -r -s /sbin/nologin -g keepalived_script -M keepalived_script
yum -y install keepalived
cd /etc/keepalived
wget https://raw.githubusercontent.com/milamber86/galera/master/keydbhc.sh
chown keepalived_script:keepalived_script /etc/keepalived/keydbhc.sh
chmod u+x /etc/keepalived/keydbhc.sh
mv -v /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_bak
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
# Note: This is the AgentX address/socket
   snmp_socket tcp:127.0.0.1:700
   enable_snmp_keepalived
   enable_traps
   enable_script_security
}

vrrp_instance VIP_1 {
    state MASTER
    interface ${VIPifname}
    virtual_router_id 101
    priority ${priority}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ${keepalivedPass}
    }
   unicast_src_ip ${IPnode1}     # Unicast specific option, this is the IP of the interface keepalived listens on
   unicast_peer {                # Unicast specific option, this is the IP of the peer instance
     ${IPnode2}
   }
    virtual_ipaddress {
        ${IPVIP}
    }
}

virtual_server ${IPVIP} 9736 {
    delay_loop 20
    lb_kind NAT
    lb_algo wrr
    protocol TCP

    real_server ${IPnode1} 6379 {
        weight 6400
	MISC_CHECK {
                    misc_path"/etc/keepalived/keydbhc.sh ${IPnode1} 6379"
                    misc_timeout 5
                    }
	}
    real_server ${IPnode2} 6379 {
        weight 1
	MISC_CHECK {
                    misc_path"/etc/keepalived/keydbhc.sh ${IPnode2} 6379"
                    misc_timeout 5
                    }
	}
}
EOF

systemctl enable keepalived
systemctl start keepalived
systemctl status keepalived
exit 0
