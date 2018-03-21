#!/bin/bash -e
# Creates some basic elements on an empty overcloud deployment (from tripleo-quickstart):
# m1.nano flavor, cirros image, public and private networks to match the other scripts

if [[ -e ~/overcloudrc ]]; then
    echo "Sourcing overcloud credentials"
    source ~/overcloudrc
else
    echo "Could not find any credentials file"
    exit 1
fi

CIRROS=/tmp/cirros.img

# Upload cirros
if ! openstack image show "cirros" > /dev/null 2>&1
then
    CIRROS_VER=0.4.0
    curl -LS -o "${CIRROS}" http://download.cirros-cloud.net/${CIRROS_VER}/cirros-${CIRROS_VER}-x86_64-disk.img
    openstack image create "cirros" \
      --file "${CIRROS}" \
      --disk-format qcow2 --container-format bare \
      --public
fi

# Flavor
if ! openstack flavor show m1.nano > /dev/null 2>&1
then
    openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano
fi

# Public network (direct access)
if ! openstack network show nova > /dev/null 2>&1
then
    openstack network create nova --share --external --provider-network-type flat --provider-physical-network datacentre
    openstack subnet create external_subnet --network nova --subnet-range 192.168.24.0/24 --gateway 192.168.24.1 --allocation-pool start=192.168.24.100,end=192.168.24.120 --no-dhcp
fi

# Private network
if ! openstack network show private > /dev/null 2>&1
then
    openstack network create private --provider-network-type vxlan
    openstack subnet create private-subnet --network private --subnet-range 172.24.4.0/24 --gateway 172.24.4.1 --dns-nameserver 8.8.8.8
fi

# And link them both
if ! openstack router show router1 > /dev/null 2>&1
then
    openstack router create router1
    openstack router set --external-gateway nova router1
    openstack router add subnet router1 private-subnet
fi

# Cleanup
rm -f "${CIRROS}"
