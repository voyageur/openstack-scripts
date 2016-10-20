#!/bin/bash -e

. $(dirname "${BASH_SOURCE}")/custom.sh

neutron net-update --port_security_enabled=False private
for port in p1 p2 p3 p4 p5 p6 source_port dest_port
do
    neutron port-create --name "${port}" private
done

# SFC VMs
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p1)" \
    --nic port-id="$(neutron port-show -f value -c id p2)" \
    vm1
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p3)" \
    --nic port-id="$(neutron port-show -f value -c id p4)" \
    vm2
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id p5)" \
    --nic port-id="$(neutron port-show -f value -c id p6)" \
    vm3

# Demo VMs
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id source_port)" \
    source_vm
nova boot --image "${IMAGE}" --flavor "${FLAVOR}" \
    --key-name "${SSH_KEYNAME}" --security-groups "${SECGROUP}" \
    --nic port-id="$(neutron port-show -f value -c id dest_port)" \
    dest_vm

# Sample classifier
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix 22.1.20.1/32 \
    --destination-ip-prefix 172.4.5.6/32 \
    --protocol tcp \
    --source-port 23:23 \
    --destination-port 100:100 \
    --logical-source-port p1 \
    FC1

# Demo classifier
SOURCE_IP=$(openstack port show source_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)
DEST_IP=$(openstack port show dest_port -f value -c fixed_ips|grep "ip_address='[0-9]*\."|cut -d"'" -f2)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port source_port \
    FC_demo

neutron port-pair-create --ingress=p1 --egress=p2 PP1
neutron port-pair-create --ingress=p3 --egress=p4 PP2
neutron port-pair-create --ingress=p5 --egress=p6 PP3

neutron port-pair-group-create --port-pair PP1 --port-pair PP2 PG1
neutron port-pair-group-create --port-pair PP3 PG2

neutron port-chain-create --port-pair-group PG1 --port-pair-group PG2 --flow-classifier FC1 --flow-classifier FC_demo PC1

# Basic demo web server
ssh cirros@${DEST_IP} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# Enable eth1 interface, add static routing
for sfc_port in p1 p3 p5
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
