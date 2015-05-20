#!/bin/bash -       
#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system and run a wifi access 
#                 point inside a docker container
#author		 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage		 :bash docker_ap.sh
#notes           :Install iptables (with nat kernel module) and docker to use this
#                 script.
#bash_version    :
#==============================================================================all

echo " ___          _               _   ___"  
echo "|   \ ___  __| |_____ _ _    /_\ | _ \\"
echo "| |) / _ \/ _| / / -_) '_|  / _ \|  _/"
echo "|___/\___/\__|_\_\___|_|   /_/ \_\_|  "
echo ""

### Local variables

IFACE="wlan5"
SUBNET="192.168.7.0"
IP_AP="192.168.7.1"
NETMASK="/24"

### Check if network-manager is running

if ps aux | grep -v grep | grep network-manager > /dev/null
then
    echo [+] Network manager is running
    echo [+] Turning nmcli wifi off
    # Fix hostapd bug in Ubuntu 14.04
    nmcli nm wifi off
else
    echo [+] Network manager is stopped
fi

rfkill unblock wifi
ifconfig $IFACE up

### Assign IP to the wifi interface
echo [+] Configuring $IFACE with IP address $IP_AP 
ip addr flush dev $IFACE
ip addr add $IP_AP$NETMASK dev $IFACE

### iptables rules for NAT
echo [+] Adding natting rule to iptables
iptables -t nat -A POSTROUTING -s $SUBNET$NETMASK ! -d $SUBNET$NETMASK -j MASQUERADE

### Enable IP forwarding
echo [+] Enabling IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

### Start the docker (baseimage)
echo [+] Starting the docker container
sudo docker run --rm -t -i --net=host --privileged fgg89/ubuntu-ap /sbin/my_init -- bash -l
