#!/bin/bash -e
# Creates some basic elements on an empty overcloud deployment (from tripleo-quickstart):
# m1.nano flavor, cirros image, "private" network to match the other scripts

if [[ -e ~/overcloudrc ]]; then
    echo "Sourcing overcloud credentials"
    source ~/overcloudrc
else
    echo "Could not find any credentials file"
    exit 1
fi

CIRROS=/tmp/cirros.img

# Upload cirros
curl -LS -o "${CIRROS}" http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
openstack image create "cirros" \
  --file "${CIRROS}" \
  --disk-format qcow2 --container-format bare \
  --public

# Flavor
openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano

# Network
openstack network create private --external --provider-network-type flat --provider-physical-network datacentre
openstack subnet create private-subnet --network private --gateway 192.168.24.1 --subnet-range 192.168.24.0/24 --allocation-pool start=192.168.24.100,end=192.168.24.120 --no-dhcp

# Cleanup
rm -f "${CIRROS}"
