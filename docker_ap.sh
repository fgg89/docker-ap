#!/bin/bash -       
#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system for running wireless
#                 access point inside a docker container.
#                 The docker container has unique access to the physical wireless 
#                 interface (--net=none). 
#author		 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage		 :bash docker_ap.sh <interface> <start|stop>
#notes           :Install iptables (with nat kernel module) and docker to use this
#                 script.
#bash_version    :
#==============================================================================all 

### Variables
PATHSCRIPT=`pwd`
PATHUTILS=$PATHSCRIPT/utils
IMAGE_NAME="fgg89/docker-ap"

SSID="DockerAP"
PASSPHRASE="dockerap123"
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
NAME="ap-container"

# Use param 2 or default
IFACE=${2:-wlan5}

PHY=`cat /sys/class/net/$IFACE/phy80211/name`

#################################################################
# print_banner function						#
#################################################################
print_banner () {

    echo " ___          _               _   ___"  
    echo "|   \ ___  __| |_____ _ _    /_\ | _ \\"
    echo "| |) / _ \/ _| / / -_) '_|  / _ \|  _/"
    echo "|___/\___/\__|_\_\___|_|   /_/ \_\_|  "
    echo ""

}

#################################################################
# init function							#
#################################################################
# setup the system (check running dnsmasq, nmcli, unblock wifi) #
# iptables rule for ap						#
# enable ip_forwarding						#
# generate conf files for hostapd and dnsmasq			#
#################################################################
init () {

    # Checking if the docker image has been already pulled
    # TODO: Can be improved
    IMG=`docker inspect --format "{{.ContainerConfig.Image}}" $IMAGE_NAME > /dev/null 2>&1`
    if [ "$IMG" == "docker-ap" ] 
    then
        echo [INFO] Docker image $IMAGE_NAME found
    else
        echo [INFO] Docker image $IMAGE_NAME not found
        echo [+] "Pulling $IMAGE_NAME (This may take a while...)"
        docker pull $IMAGE_NAME > /dev/null 2>&1
    fi

    ### Check if dnsmasq is running
    if ps aux | grep -v grep | grep dnsmasq > /dev/null
    then
       echo [INFO] dnsmasq is running
       echo [+] Turning dnsmasq off
       killall dnsmasq
       # TODO: The host now lost internet connection...
    else
        echo [INFO] dnsmasq is stopped
    fi

    ### Check if network-manager is running
    if ps aux | grep -v grep | grep network-manager > /dev/null
    then
        echo [INFO] Network manager is running
        echo [+] Turning nmcli wifi off
        # Fix hostapd bug in Ubuntu 14.04
        nmcli nm wifi off
    else
        echo [INFO] Network manager is stopped
    fi

    # Unblock wifi and bring the wireless interface up
    rfkill unblock wifi
    ifconfig $IFACE up

    echo [+] Adding natting rule to iptables
    iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    ### Enable IP forwarding
    echo [+] Enabling IP forwarding 
    echo 1 > /proc/sys/net/ipv4/ip_forward


echo [+] Generating hostapd.conf 
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

echo [+] Generating dnsmasq.conf 
### Generating dnsmasq conf file
cat <<EOF > $PATHSCRIPT/dnsmasq.conf
no-resolv 
server=8.8.8.8
interface=lo,$IFACE
no-dhcp-interface=lo
dhcp-range=$SUBNET.20,$SUBNET.254,255.255.255.0,12h
EOF


}

#################################################################
# service_start function					#
#################################################################
# start the docker container (--net=none)			#
# allocate_ifaces.sh						#
  # allocate the wireless interface in the docker container	#
  # allocate a pair of veth for internet access			#
# give an ip to the wireless interface				#
# iptables rule for ap						#
# enable ip_forwarding						#
# start hostapd and dnsmasq in the container			#
#################################################################

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

#################################################################
# service_stop function						#
#################################################################
# stop and remove the docker container 				#
# deallocate_ifaces.sh						#
  # completes the cleaning of deallocation			#
# give an ip to the wireless interface				#
# remove iptables rule for ap in host				#
# disable ip_forwarding in host					#
# remove the conf files for hostapd and dnsmasq			#
#################################################################
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
    echo [+] Enabling dnsmasq...
    service dnsmasq restart
}


#################################################################
#			MAIN					#
#################################################################
#if [ "$#" -ne 2 ]; then
#    echo "Usage: docker_ap.sh <interface> <start|stop>"
#    exit 1
#fi 

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
    echo "Usage: docker_ap <start|stop> [wlan_iface]"
else
    echo "Please enter a valid argument"
fi
