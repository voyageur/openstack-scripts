#!/bin/bash -e
# Basic configuration of the devstack
# Credentials, SSH keys, security group

# If you want to use your own SSH key (with forwarding agent)
#CUSTOM_SSH_KEYNAME="defiant"
#CUSTOM_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIxK0j9EvqUDndkB8h+MKA6TqNstTyw66VVBuMVywqYxtH73qOzzBjSNIAlO1nT7zL2BBN3kQNL84nmbGevwckB+lzIZrc+Tzc2a1VhopthemftZw0XUnn6+uf8UU4K9d17434u/U12F3ZDOprJypmr9xOOy0zrX09ycZqMrs0B5QoZb6zCP5FzZTo8qGL0sB01zAyYgxw5u+RK8bpNGfTXJ5lakXfdVdB71Pubu1FybIqgR9vIg46FkygMZygT33jUt5pOGKddG++/4t0fHSv21OgXfFb6HNZHDFELY5b8hBRZmuQ+vMpvu+gsD5IabLj3B/rAwtgulCN/gCHqgxR bcafarel@defiant.redhat.com"
#SSH_KEYNAME=${CUSTOM_SSH_KEYNAME}

# Else use local key (will be generated if it does not exist)
SSH_KEYNAME="default"

# Standard project and security group names
PROJECT="demo"
SECGROUP="default"

# Source credentials
[[ -e ~/devstack/openrc ]] && source ~/devstack/openrc "${PROJECT}" "${PROJECT}"
[[ -e ~/keystonerc_${PROJECT} ]] && source ~/keystonerc_${PROJECT}

# Use nano or tiny flavor
FLAVOR=$(openstack flavor list -f value -c Name |grep nano|| echo m1.tiny)
# Find cirros image
IMAGE=$(openstack image list -f value -c Name|grep cirros|grep -v 'ramdisk\|kernel')

if [ "${SSH_KEYNAME}" = "default" ]
then
    [[ -e ~/.ssh/id_rsa ]] || ssh-keygen -f ~/.ssh/id_rsa
    if ! openstack keypair show default > /dev/null 2>&1
    then
        openstack keypair create --public-key ~/.ssh/id_rsa.pub default
    fi
else
    if ! openstack keypair show ${CUSTOM_SSH_KEYNAME} > /dev/null 2>&1
    then
        openstack keypair create --public-key <( echo ${CUSTOM_SSH_KEY} ) ${CUSTOM_SSH_KEYNAME}
    fi
fi

# Note: check on existing rules is basic
SECGROUP_RULES=$(openstack security group show "${SECGROUP}" -f value -c rules)
if ! echo "${SECGROUP_RULES}" | grep -q icmp
then 
    openstack security group rule create --proto icmp "${SECGROUP}"
fi
for port in 22 80
do
    if ! echo "${SECGROUP_RULES}" | grep -q "port_range_max='${port}', port_range_min='${port}'"
    then 
        openstack security group rule create --proto tcp --dst-port ${port} "${SECGROUP}"
    fi
done
