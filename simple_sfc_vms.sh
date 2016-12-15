#!/bin/bash -e
# Creates some instances for networking-sfc demo/development:
# a web server, another instance to use as client
# three "service VMs" with two interface that will just route the packets to/from each interface

. $(dirname "${BASH_SOURCE}")/custom.sh
. $(dirname "${BASH_SOURCE}")/tools.sh

# Disable port security (else packets would be rejected when exiting the service VMs)
neutron net-update --port_security_enabled=False private

# Create network ports for all VMs
for port in p1in p1out p2in p2out p3in p3out source_vm_port dest_vm_port
do
    neutron port-create --name "${port}" private
done

# SFC VMs
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p1in)" \
    --nic port-id="$(neutron port-show -f value -c id p1out)" \
    vm1
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p2in)" \
    --nic port-id="$(neutron port-show -f value -c id p2out)" \
    vm2
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p3in)" \
    --nic port-id="$(neutron port-show -f value -c id p3out)" \
    vm3

# Demo VMs
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id source_vm_port)" \
    source_vm
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id dest_vm_port)" \
    dest_vm

# HTTP Flow classifier (catch the web traffic from source_vm to dest_vm)
SOURCE_IP=$(openstack port show source_vm_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)
DEST_IP=$(openstack port show dest_vm_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port source_vm_port \
    FC_http

# UDP flow classifier (catch all UDP traffic from source_vm to dest_vm, like traceroute)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol udp \
    --logical-source-port source_vm_port \
    FC_udp

# Get easy access to the VMs
route_to_subnetpool

# Create the port pairs for all 3 VMs
neutron port-pair-create --ingress=p1in --egress=p1out PP1
neutron port-pair-create --ingress=p2in --egress=p2out PP2
neutron port-pair-create --ingress=p3in --egress=p3out PP3

# And the port pair groups
neutron port-pair-group-create --port-pair PP1 --port-pair PP2 PG1
neutron port-pair-group-create --port-pair PP3 PG2

# The complete chain
neutron port-chain-create --port-pair-group PG1 --port-pair-group PG2 --flow-classifier FC_udp --flow-classifier FC_http PC1

# Start a basic demo web server
ssh cirros@${DEST_IP} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# On service VMs, enable eth1 interface and add static routing
for sfc_port in p1in p2in p3in
do
    ssh -T cirros@$(openstack port show ${sfc_port} -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2) <<EOF
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo /etc/init.d/S40network restart
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo ip route add ${SOURCE_IP} dev eth0
sudo ip route add ${DEST_IP} dev eth1

EOF
done
