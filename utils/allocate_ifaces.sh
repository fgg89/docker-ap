#!/bin/bash
#title           :allocate_ifaces.sh
#description     :This script will passthrough the wlan interface
#                 to the docker container.
#		          It will also configure a pair of veth interfaces
#                 for internet access. 
#author          :Fran Gonzalez
#date            :20150619
#version         :0.1    
#usage           :bash allocate_ifaces.sh <pid> <wlan_phy>
#bash_version    :
#=============================================================all 

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <pid> <wlan_phy>"
    exit 1
fi

PID=$1
PHY=$2

BRIDGE="docker0"
WAN_IP="172.17.0.99/16"
GW="172.17.0.1"

# Assign phy wireless interface to the container 
mkdir -p /var/run/netns
ln -s /proc/$PID/ns/net /var/run/netns/$PID

iw phy $PHY set netns $PID

# The rest is necessary ONLY if using --net=none in docker:

# Create a pair of "peer" interfaces veth0 and veth1,
# bind the veth0 end to the bridge, and bring it up
ip link add veth0 type veth peer name veth1
brctl addif $BRIDGE veth0
ip link set veth0 up

# Place veth1 inside the container's network namespace,
ip link set veth1 netns $PID
ip netns exec $PID ip link set dev veth1 name eth0
ip netns exec $PID ip link set eth0 address 12:34:56:78:9a:bc
ip netns exec $PID ip link set eth0 up
ip netns exec $PID ip addr add $WAN_IP dev eth0
ip netns exec $PID ip route add default via $GW

