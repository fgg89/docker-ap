#!/bin/bash -       
#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system
#                 for running a wireless access point inside a
#                 docker container.
#                 The docker container has unique access to the
#                 physical wireless interface. 
#author			 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage			 :bash docker_ap.sh <start|stop> <interface>
#bash_version    :4.3.11(1)-release (x86_64-pc-linux-gnu)
#dependencies	 :docker, iw, grep, rfkill, iptables (with nat),
#				  cat, ip, bridge-utils
#=============================================================all 

BLACK='\e[0;30m'
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;34m'
MAGENTA='\e[0;35m'
CYAN='\e[0;36m'
WHITE='\e[0;37m'
NC='\e[0m'

ROOT_UID="0"

PATHSCRIPT=`pwd`
PATHUTILS=$PATHSCRIPT/utils

DOCKER_IMAGE="fgg89/docker-ap"
DOCKER_IMAGE_NAME="docker-ap"
DOCKER_NAME="ap-container"

SSID="DockerAP"
PASSPHRASE="dockerap123"
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
CHANNEL="6"
DNS_SERVER="8.8.8.8"

if [[ -z "$2" ]]
then
	echo [ERROR] No interface provided. Exiting...
	exit 1
fi
clear

IFACE=${2}

# Find the physical interface for the given wireless interface
PHY=`cat /sys/class/net/$IFACE/phy80211/name`

# Check run as root
if [ "$UID" -ne "$ROOT_UID" ] ; then
    echo "You must be root to run this script!"
    exit 1
fi

# Argument check
if [ "$#" -eq 0 ] || [ "$#" -gt 2 ] 
then
    echo "Usage: $0 <start|stop> [wlan_iface]"
    exit 1
fi

print_banner () {

    echo " ___          _               _   ___"  
    echo "|   \ ___  __| |_____ _ _    /_\ | _ \\"
    echo "| |) / _ \/ _| / / -_) '_|  / _ \|  _/"
    echo "|___/\___/\__|_\_\___|_|   /_/ \_\_|  "
    echo ""

}

init () {

    # Number of phy interfaces
    NUM_PHYS=`iw dev | grep phy | wc -l`
    echo -e "${BLUE}[INFO]${NC} Number of physical wireless interfaces connected: ${GREEN}$NUM_PHYS${NC}"
    
    # Check that the requested iface is available
    if ! [ -e /sys/class/net/$IFACE ]
    then
        echo -e "${RED}[ERROR]${NC} The interface provided does not exist. Exiting..."
        exit 1
    fi
    
    # Checking if the docker image has been already pulled
    IMG=`docker inspect --format "{{.ContainerConfig.Image}}" $DOCKER_IMAGE`
    if [ "$IMG" == $DOCKER_IMAGE ] 
    then
        echo -e "${BLUE}[INFO]${NC} Docker image ${GREEN}$DOCKER_IMAGE${NC} found"
    else
        echo -e "${BLUE}[INFO]${NC} Docker image ${RED}$DOCKER_IMAGE${NC} not found"
        echo -e "[+] Pulling ${GREEN}$DOCKER_IMAGE${NC} (This may take a while...)"
        docker pull $DOCKER_IMAGE > /dev/null 2>&1
    fi

    ### Check if hostapd is running in the host
    if ps aux | grep -v grep | grep hostapd > /dev/null
    then
       echo -e "${BLUE}[INFO]${NC} hostapd is running"
       killall hostapd
    else
        echo -e "${BLUE}[INFO]${NC} hostapd is stopped"
    fi

    # Unblock wifi and bring the wireless interface up
    echo -e "${BLUE}[INFO]${NC} Unblocking wifi and setting ${IFACE} up"
    rfkill unblock wifi
    ifconfig $IFACE up

    echo "[+] Adding natting rule to iptables (host)"
    iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    
    ### Enable IP forwarding
    echo "[+] Enabling IP forwarding (host)" 
    echo 1 > /proc/sys/net/ipv4/ip_forward

    ### Generating hostapd conf file
    echo -e "[+] Generating hostapd.conf"
    sed -e "s/_SSID/$SSID/g" -e "s/_IFACE/$IFACE/" -e "s/_CHANNEL/$CHANNEL/g" -e "s/_PASSPHRASE/$PASSPHRASE/g" $PATHSCRIPT/templates/hostapd.template > $PATHSCRIPT/hostapd.conf

    ### Generating dnsmasq conf file
    echo -e "[+] Generating dnsmasq.conf" 
    sed -e "s/_DNS_SERVER/$DNS_SERVER/g" -e "s/_IFACE/$IFACE/" -e "s/_SUBNET_FIRST/$SUBNET.20/g" -e "s/_SUBNET_END/$SUBNET.254/g" $PATHSCRIPT/templates/dnsmasq.template > $PATHSCRIPT/dnsmasq.conf

}


service_start () { 
    echo -e "[+] Starting the docker container with name ${GREEN}$DOCKER_NAME${NC}"
    # docker run --rm -t -i --name $NAME --net=host --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf fgg89/ubuntu-ap /sbin/my_init -- bash -l
    docker run -d --name $DOCKER_NAME --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf $DOCKER_IMAGE /sbin/my_init > /dev/null 2>&1
    pid=`docker inspect -f '{{.State.Pid}}' $DOCKER_NAME`
    # To configure the networking (this is not necessary if --net=none is not used)
    echo -e "${BLUE}[INFO]${NC} $IFACE is now exclusively handled to the docker container"
    echo -e "[+] Configuring wiring in the docker container and attaching its eth to the default docker bridge"
    bash $PATHUTILS/allocate_ifaces.sh $pid $PHY 
    
    ### Assign an IP to the wifi interface
    echo -e "[+] Configuring ${GREEN}$IFACE${NC} with IP address ${GREEN}$IP_AP${NC}"
    ip netns exec $pid ip addr flush dev $IFACE
    ip netns exec $pid ip link set $IFACE up
    ip netns exec $pid ip addr add $IP_AP$NETMASK dev $IFACE

    ### iptables rules for NAT
    echo "[+] Adding natting rule to iptables (container)"
    ip netns exec $pid iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    
    ### Enable IP forwarding
    echo "[+] Enabling IP forwarding (container)"
    ip netns exec $pid echo 1 > /proc/sys/net/ipv4/ip_forward
    ### start hostapd and dnsmasq in the container
    echo -e "[+] Starting ${GREEN}hostapd${NC} and ${GREEN}dnsmasq${NC} in the docker container ${GREEN}$DOCKER_NAME${NC}"
    docker exec $DOCKER_NAME start_ap

}


service_stop () { 
    echo -e "[-] Stopping ${GREEN}$DOCKER_NAME${NC}..."
    docker stop $DOCKER_NAME > /dev/null 2>&1 
    echo -e "[-] Removing ${GREEN}$DOCKER_NAME${NC}..."
    docker rm $DOCKER_NAME > /dev/null 2>&1 
    echo [-] Reversing iptables configuration...
    iptables -t nat -D POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE > /dev/null 2>&1
    echo [-] Disabling ip forwarding...
    echo 0 > /proc/sys/net/ipv4/ip_forward
    echo [-] Removing conf files...
    if [ -e $PATHSCRIPT/hostapd.conf ]
    then
        rm $PATHSCRIPT/hostapd.conf
    fi
    if [ -e $PATHSCRIPT/dnsmasq.conf ]
    then
        rm $PATHSCRIPT/dnsmasq.conf
    fi
    echo [-] Removing IP address in $IFACE...
    ip addr del $IP_AP$NETMASK dev $IFACE > /dev/null 2>&1
}


if [ "$1" == "start" ]
then
    
    print_banner
    init
    service_start
elif [ "$1" == "stop" ]
then
    clear
    service_stop
    bash $PATHUTILS/deallocate_ifaces.sh
elif [ "$1" == "help" ]
then
    echo "Usage: $0 <start|stop> <interface>"
else
    echo "Please enter a valid argument"
    echo "Usage: $0 <start|stop> <interface>"
fi
