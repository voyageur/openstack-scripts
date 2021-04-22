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
            --network "${PRIV_NETWORK}" "${inst}"

        floating=$(openstack floating ip create "${PUB_NETWORK}" -f value -c floating_ip_address)
        openstack server add floating ip "${inst}" "${floating}"
    fi
done

route_to_subnetpool

VM_IPS=$(openstack floating ip list -f value -c "Floating IP Address" | grep -v None)
# Let the VMs boot
for vm_ip in ${VM_IPS}
do
    echo "Waiting for ${vm_ip} connection"
    wait_for_ssh cirros@${vm_ip}
done

# Basic web server
for vm_ip in ${VM_IPS}
do
    basic_web_server cirros@${vm_ip}
done

openstack server list
