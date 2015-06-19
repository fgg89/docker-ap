#!/bin/bash -       
#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system and run a wifi access 
#                 point inside a docker container
#author		 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage		 :bash docker_ap.sh start|stop
#notes           :Install iptables (with nat kernel module) and docker to use this
#                 script.
#bash_version    :
#==============================================================================all 

### Variables

SSID="DockerAP"
PASSPHRASE="dockerap123"
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
PATHSCRIPT=`pwd`
NAME="ap-container"

IFACE=$1
# Find out mapping wlanX -> phyX
PHY=`cat /sys/class/net/$IFACE/phy80211/name`

#if [ "$IFACE" == "" ]
#then
#    IFACE="wlan5"
#fi

clear

init () {

    echo " ___          _               _   ___"  
    echo "|   \ ___  __| |_____ _ _    /_\ | _ \\"
    echo "| |) / _ \/ _| / / -_) '_|  / _ \|  _/"
    echo "|___/\___/\__|_\_\___|_|   /_/ \_\_|  "
    echo ""


    ### Check if dnsmasq is running
    if ps aux | grep -v grep | grep dnsmasq > /dev/null
    then
       echo [+] dnsmasq is running
       echo [+] Turning dnsmasq off
       killall dnsmasq
    else
        echo [+] dnsmasq is stopped
    fi

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
#    ip addr add $IP_AP$NETMASK dev $IFACE

    ### iptables rules for NAT
    echo [+] Adding natting rule to iptables
    iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE

    ### Enable IP forwarding
    echo [+] Enabling IP forwarding 
    echo 1 > /proc/sys/net/ipv4/ip_forward

### Generating hostapd conf file
cat <<EOF > $PATHSCRIPT/hostapd.conf
ssid=$SSID
interface=$IFACE
hw_mode=g
channel=1
wpa=2
wpa_passphrase=$PASSPHRASE
wpa_key_mgmt=WPA-PSK
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOF

### Generating dnsmasq conf file
cat <<EOF > $PATHSCRIPT/dnsmasq.conf
no-resolv 
server=8.8.8.8
interface=lo,$IFACE
no-dhcp-interface=lo
dhcp-range=$SUBNET.20,$SUBNET.254,255.255.255.0,12h
EOF

}

service_start () { 
    echo [+] Starting the docker container
    ## --rm, remove this flag if you want the container to remain after stopping it
#    docker run --rm -t -i --name $NAME --net=host --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf fgg89/ubuntu-ap /sbin/my_init -- bash -l
    docker run -d --name $NAME --net=none --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf docker-ap /sbin/my_init
    pid=`docker inspect -f '{{.State.Pid}}' $NAME`
    ./allocate_ifaces.sh $pid $PHY 

    ip netns exec $pid ip link set $IFACE up
    ip netns exec $pid ip addr add $IP_AP$NETMASK dev $IFACE
 
    docker exec $NAME start_ap.sh   
}

service_stop () { 
    echo [+] Stopping the docker container and reverting system configuration
    docker stop $NAME
    docker rm $NAME
#    ip addr del $IP_AP$NETMASK dev $IFACE
    iptables -t nat -D POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    echo 0 > /proc/sys/net/ipv4/ip_forward
    rm $PATHSCRIPT/hostapd.conf
    rm $PATHSCRIPT/dnsmasq.conf
}

if [ "$#" -ne 2 ]; then
    echo "Usage: docker_ap.sh [interface] [start|stop]"
    exit 1
fi 

if [ "$2" == "start" ]
then
    init
    service_start
elif [ "$2" == "stop" ]
then
    service_stop
    ./deallocate_ifaces.sh
else
    echo "Please enter a valid argument"
fi

