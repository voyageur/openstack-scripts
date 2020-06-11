#!/bin/bash -e
# Common functions

function route_to_subnetpool {
    # Neutron no longer sets route to the created net:
    # https://github.com/openstack-dev/devstack/commit/1493bdeba24674f6634160d51b8081c571df4017
    # Add/replace it here for ease of use
    local ROUTER=$(openstack router list -f value -c ID)
    # No router
    if [ -z "${ROUTER}" ]; then
        return
    fi
    # No namespace (different node?)
    if ! sudo ip netns list | grep -q qrouter-"${ROUTER}"; then
        return
    fi

    local NET_GATEWAY=$(sudo ip netns exec qrouter-"${ROUTER}" ip -4 route get 8.8.8.8 | head -n1 | awk '{print $7}')
    # Filter IPv6 pool out
    local SUBNET_POOL=$(openstack subnet pool list -f value -c Prefixes | grep -v : | sed -e "s/.*'\(.*\)'.*/\1/")

    sudo ip route replace "${SUBNET_POOL}" via "${NET_GATEWAY}"
}

function wait_for_ssh {
    # Try to connect to SSH
    local SSH=${1}
    local RETRIES=${2:-5}

    for i in $(seq ${RETRIES})
    do
        STATUS=$(ssh -o "ConnectTimeout=10" "${SSH}" echo ok 2> /dev/null || true)
        if [ "${STATUS}" == "ok" ]
        then
            return 0
        fi
    done

    return 1
}
