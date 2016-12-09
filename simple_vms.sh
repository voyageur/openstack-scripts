#!/bin/bash -e
# Creates 2 cirros VMs with a simple web server
. $(dirname "${BASH_SOURCE}")/custom.sh
. $(dirname "${BASH_SOURCE}")/tools.sh

for inst in cirros1 cirros2
do
    if ! nova show "${inst}" > /dev/null 2>&1
    then
        nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
            --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
            "${inst}"

        floating=$(openstack ip floating create public -f value -c floating_ip_address)
        openstack ip floating add "${floating}" "${inst}"
    fi
done

# Let the VMs boot
sleep 5
route_to_subnetpool

# Basic web server
for fixed_ip in $(openstack ip floating list -f value -c "Fixed IP Address")
do
    ssh cirros@${fixed_ip} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'
done

openstack server list
