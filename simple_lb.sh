#!/bin/bash -e
# Creates an Octavia load balancer on HTTP port
# Some instances should already be running as they will be added as members
# (simple_vms.sh can create the needed instances)

. $(dirname "${BASH_SOURCE}")/custom.sh

LB="lb1"
POOL="pool1"
LISTENER="listener1"

neutron lbaas-loadbalancer-create $(neutron subnet-list | awk '/ private-subnet / {print $2}') --name ${LB}

# Wait for creation
while [ $(neutron lbaas-loadbalancer-show ${LB} -f value -c provisioning_status) != "ACTIVE" ];
do
	sleep 5;
done

neutron lbaas-listener-create --loadbalancer ${LB} --protocol HTTP --protocol-port 80 --name ${LISTENER}
neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --listener ${LISTENER} --protocol HTTP --name ${POOL}

for ip in $(openstack server list -f value -c Networks| sed "s/.*\(10.0[^,]*\).*/\1/"); do
	if neutron lbaas-member-show ${ip} ${POOL} > /dev/null;
	then
		continue
	fi
	until neutron lbaas-member-create  --subnet private-subnet --address ${ip} --name ${ip} --protocol-port 80 ${POOL}
	do
		sleep 5
	done
done
