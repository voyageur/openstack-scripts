#!/bin/bash -e
# Creates 2 cirros VMs with a simple web server
. $(dirname "${BASH_SOURCE}")/custom.sh
. $(dirname "${BASH_SOURCE}")/tools.sh

for inst in cirros1 cirros2
do
    if ! openstack server show "${inst}" > /dev/null 2>&1
    then
        openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
            --key-name "${SSH_KEYNAME}" --security-group "${SECGROUP}" \
            "${inst}"

        floating=$(openstack floating ip create public -f value -c floating_ip_address)
        openstack server add floating ip "${inst}" "${floating}"
    fi
done

# Let the VMs boot
sleep 5
route_to_subnetpool

# Basic web server
for fixed_ip in $(openstack floating ip list -f value -c "Fixed IP Address" | grep -v None)
do
    ssh cirros@${fixed_ip} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'
done

openstack server list
