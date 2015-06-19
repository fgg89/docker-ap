#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: allocate-ifaces.sh [pid] [wlan_phy]"
    exit 1
fi

pid=$1
PHY=$2
#pid=`docker inspect -f '{{.State.Pid}}' $DOCKER_NAME`

bridge="br0"

##################################################
# Assign phy wireless interface to the container #
##################################################

mkdir -p /var/run/netns
ln -s /proc/$pid/ns/net /var/run/netns/$pid

iw phy $PHY set netns $pid

####################################
# Create eth0 with internet access #
####################################

# Create a pair of "peer" interfaces veth0 and veth1,
# bind the veth0 end to the bridge, and bring it up

ip link add veth0 type veth peer name veth1
brctl addif $bridge veth0
ip link set veth0 up

# Place veth1 inside the container's network namespace,
# rename to eth0, and activate it with a free IP

ip link set veth1 netns $pid
ip netns exec $pid ip link set dev veth1 name eth0
ip netns exec $pid ip link set eth0 address 12:34:56:78:9a:bc
ip netns exec $pid ip link set eth0 up
ip netns exec $pid ip addr add 172.16.250.198/24 dev eth0
ip netns exec $pid ip route add default via 172.16.250.1

