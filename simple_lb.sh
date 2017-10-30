#!/bin/bash -e
# Creates an Octavia load balancer on HTTP port
# Some instances should already be running as they will be added as members
# (simple_vms.sh can create the needed instances)

. $(dirname "${BASH_SOURCE}")/custom.sh

LB="lb1"
POOL="pool1"
LISTENER="listener1"

openstack loadbalancer create --vip-subnet-id $(openstack subnet show private-subnet -f value -c id) --name ${LB}

# Wait for creation
while [ $(openstack loadbalancer show ${LB} -f value -c provisioning_status) != "ACTIVE" ];
do
    sleep 5;
done

openstack loadbalancer listener create --protocol HTTP --protocol-port 80 --name ${LISTENER} ${LB}
sleep 5
openstack loadbalancer pool create --lb-algorithm ROUND_ROBIN --listener ${LISTENER} --protocol HTTP --name ${POOL}


for ip in $(openstack server list -f value -c Networks | sed "s/.*\(\(10.0\|192.168\)[^,]*\).*/\1/"); do
    if openstack loadbalancer member show ${ip} ${POOL} 2> /dev/null;
    then
        continue
    fi
    until openstack loadbalancer member create --subnet-id private-subnet --address ${ip} --name ${ip} --protocol-port 80 ${POOL}
    do
        sleep 5
    done
done
