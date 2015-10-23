#!/bin/bash -       
#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system for running wireless
#                 access point inside a docker container.
#                 The docker container has unique access to the physical wireless 
#                 interface (--net=none). 
#author			 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage			 :bash docker_ap.sh <start|stop> <interface>
#notes           :Install iptables (with nat kernel module) and docker to use this
#                 script.
#bash_version    :4.3.11(1)-release (x86_64-pc-linux-gnu)
#==============================================================================all 

ROOT_UID="0"

#Check if run as root
if [ "$UID" -ne "$ROOT_UID" ] ; then
	echo "You must be root to run this script!"
  	exit 1
fi

# Argument check
#if [ "$#" -eq 0 or "$#" -gt 2 ]
if [ "$#" -eq 0 ] || [ "$#" -gt 2 ] 
then
    echo "Usage: $0 <start|stop> [wlan_iface]"
    exit 1
fi

##### Global variables #####

PATHSCRIPT=`pwd`
PATHUTILS=$PATHSCRIPT/utils
IMAGE_NAME="fgg89/docker-ap"

SSID="DockerAP"
PASSPHRASE="dockerap123"
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
CHANNEL="6"
NAME="ap-container"

DNS_SERVER="8.8.8.8"

# Second argument is the wireless interface
IFACE=${2}

# Find the physical interface for the given wireless interface
PHY=`cat /sys/class/net/$IFACE/phy80211/name`

##### print_banner function	#####
print_banner () {

    echo " ___          _               _   ___"  
    echo "|   \ ___  __| |_____ _ _    /_\ | _ \\"
    echo "| |) / _ \/ _| / / -_) '_|  / _ \|  _/"
    echo "|___/\___/\__|_\_\___|_|   /_/ \_\_|  "
    echo ""

}

##### init function	#####
# setup the system (check running dnsmasq, nmcli, unblock wifi)
# iptables rule for ap
# enable ip_forwarding
# generate conf files for hostapd and dnsmasq
init () {

	# Number of phy interfaces
	NUM_PHYS=`iw dev | grep phy | wc -l`
	echo [INFO] Number of physical wireless interfaces connected: $NUM_PHYS
	
	# TODO: Check that the requested iface is available

    # Checking if the docker image has been already pulled
    IMG=`docker inspect --format "{{.ContainerConfig.Image}}" $IMAGE_NAME`
    if [ "$IMG" == "docker-ap" ] 
    then
        echo [INFO] Docker image $IMAGE_NAME found
    else
        echo [INFO] Docker image $IMAGE_NAME not found
        echo [+] "Pulling $IMAGE_NAME (This may take a while...)"
        docker pull $IMAGE_NAME > /dev/null 2>&1
    fi

    ### Check if hostapd is running in the host
    if ps aux | grep -v grep | grep hostapd > /dev/null
    then
       echo [INFO] hostapd is running
       killall hostapd
    else
        echo [INFO] hostapd is stopped
    fi

    # Unblock wifi and bring the wireless interface up
    rfkill unblock wifi
    ifconfig $IFACE up

    echo [+] Adding natting rule to iptables
    iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    
	### Enable IP forwarding
    echo [+] Enabling IP forwarding 
    echo 1 > /proc/sys/net/ipv4/ip_forward


	### Generating hostapd conf file
	echo [+] Generating hostapd.conf
	sed -e "s/_SSID/$SSID/g" -e "s/_IFACE/$IFACE/" -e "s/_CHANNEL/$CHANNEL/g" -e "s/_PASSPHRASE/$PASSPHRASE/g" $PATHSCRIPT/hostapd.template > $PATHSCRIPT/hostapd.conf

	### Generating dnsmasq conf file
	echo [+] Generating dnsmasq.conf 
	sed -e "s/_DNS_SERVER/$DNS_SERVER/g" -e "s/_IFACE/$IFACE/" -e "s/_SUBNET_FIRST/$SUBNET.20/g" -e "s/_SUBNET_END/$SUBNET.254/g" $PATHSCRIPT/dnsmasq.template > $PATHSCRIPT/dnsmasq.conf

}

##### service_start function #####
# start the docker container (--net=none)
# allocate_ifaces.sh
  # allocate the wireless interface in the docker container
  # allocate a pair of veth for internet access
# give an ip to the wireless interface
# iptables rule for ap
# enable ip_forwarding
# start hostapd and dnsmasq in the container
service_start () { 
    echo [+] Starting the docker container
    # docker run --rm -t -i --name $NAME --net=host --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf fgg89/ubuntu-ap /sbin/my_init -- bash -l
    docker run -d --name $NAME --net=none --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf $IMAGE_NAME /sbin/my_init > /dev/null 2>&1
    pid=`docker inspect -f '{{.State.Pid}}' $NAME`
    bash $PATHUTILS/allocate_ifaces.sh $pid $PHY 
    
    ### Assign IP to the wifi interface
    echo [+] Configuring $IFACE with IP address $IP_AP 
#    ip addr flush dev $IFACE
    ip netns exec $pid ip link set $IFACE up
    ip netns exec $pid ip addr add $IP_AP$NETMASK dev $IFACE
    ### iptables rules for NAT
    echo [+] Adding natting rule to iptables
    ip netns exec $pid iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    ### Enable IP forwarding
    echo [+] Enabling IP forwarding 
    ip netns exec $pid echo 1 > /proc/sys/net/ipv4/ip_forward
    ### start hostapd and dnsmasq in the container
    echo [+] Starting hostapd and dnsmasq
    docker exec $NAME start_ap.sh   

}

##### service_stop function	#####
# stop and remove the docker container
# deallocate_ifaces.sh
  # completes the cleaning of deallocation
# give an ip to the wireless interface
# remove iptables rule for ap in host
# disable ip_forwarding in host
# remove the conf files for hostapd and dnsmasq
service_stop () { 
    echo [-] Stopping $NAME...
    docker stop $NAME > /dev/null 2>&1 
    echo [-] Removing $NAME...
    docker rm $NAME > /dev/null 2>&1 
#    ip addr del $IP_AP$NETMASK dev $IFACE
    echo [-] Reversing iptables configuration...
    iptables -t nat -D POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    echo [-] Disabling ip forwarding...
    echo 0 > /proc/sys/net/ipv4/ip_forward
    echo [-] Removing conf files...
    rm $PATHSCRIPT/hostapd.conf
    rm $PATHSCRIPT/dnsmasq.conf

}


if [ "$1" == "start" ]
then
    clear
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
