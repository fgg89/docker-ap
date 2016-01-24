#!/bin/bash        

#title           :docker_ap.sh
#description     :This script will configure an Ubuntu system
#                 for running a wireless access point inside a
#                 docker container.
#                 The docker container has unique access to the
#                 physical wireless interface. 
#author			 :Fran Gonzalez
#date            :20150520
#version         :0.1    
#usage			 :bash docker_ap <start|stop> [interface]
#bash_version    :4.3.11(1)-release (x86_64-pc-linux-gnu)
#dependencies	 :docker, iw, pgrep, grep, rfkill, iptables,
#				  cat, ip, bridge-utils
#=============================================================all 

#YELLOW='\e[0;33m'
#BLACK='\e[0;30m'
#CYAN='\e[0;36m'
#WHITE='\e[0;37m'
MAGENTA='\e[0;35m'
RED='\e[0;31m'
GREEN='\e[0;32m'
BLUE='\e[0;34m'
NC='\e[0m'

PATHSCRIPT=$(pwd)

ROOT_UID="0"

SSID="DockerAP"
PASSPHRASE="dockerap123"
SUBNET="192.168.7"
IP_AP="192.168.7.1"
NETMASK="/24"
CHANNEL="6"

DNS_SERVER="8.8.8.8"
BRIDGE="docker0"
WAN_IP="172.17.0.99/16"
GW="172.17.0.1"

DOCKER_NAME="ap-container"

ARCH=$(arch)
if [ "$ARCH" == "armv7l" ]
then
    DOCKER_IMAGE="fgg89/armhf-docker-ap"
elif [ "$ARCH" == "x86_64" ]
then
    DOCKER_IMAGE="fgg89/docker-ap"
else
    echo "Architecture not know. Exiting..."
    exit 1
fi

show_usage () {
    echo "Usage: $0 <start|stop> [interface]"
    exit 1
}

if [ "$1" == "help" ]
then
    show_usage
fi

# Check run as root
if [ "$UID" -ne "$ROOT_UID" ] ; then
    echo "You must be root to run this script!"
    exit 1
fi

# Argument check
if [ "$#" -eq 0 ] || [ "$#" -gt 2 ] 
then
    show_usage
fi

print_banner () {
    echo -e "${MAGENTA} ___          _               _   ___   ${NC}"
    echo -e "${MAGENTA}|   \ ___  __| |_____ _ _    /_\ | _ \\ ${NC}"
    echo -e "${MAGENTA}| |) / _ \/ _| / / -_) '_|  / _ \|  _/  ${NC}"
    echo -e "${MAGENTA}|___/\___/\__|_\_\___|_|   /_/ \_\_|    ${NC}"
    echo ""
}

init () {
    IFACE="$1"
    # Find the physical interface for the given wireless interface
    PHY=$(cat /sys/class/net/"$IFACE"/phy80211/name)
    
    # Number of phy interfaces
    NUM_PHYS=$(iw dev | grep -c phy)
    echo -e "${BLUE}[INFO]${NC} Number of physical wireless interfaces connected: ${GREEN}$NUM_PHYS${NC}"
    
    # Check that the requested iface is available
    if ! [ -e /sys/class/net/"$IFACE" ]
    then
        echo -e "${RED}[ERROR]${NC} The interface provided does not exist. Exiting..."
        exit 1
    fi
    
    # Checking if the docker image has been already pulled
    IMG_CHECK=$(docker images -q $DOCKER_IMAGE)
    if [ "$IMG_CHECK" != "" ]
    then
        echo -e "${BLUE}[INFO]${NC} Docker image ${GREEN}$DOCKER_IMAGE${NC} found"
    else
        echo -e "${BLUE}[INFO]${NC} Docker image ${RED}$DOCKER_IMAGE${NC} not found"
		# Option 1: Building
        #echo -e "[+] Building the image ${GREEN}$DOCKER_IMAGE${NC} (This may take a while...)"
        #docker build --rm -t fgg89/docker-ap .
		# Option 2: Pulling
        echo -e "[+] Pulling ${GREEN}$DOCKER_IMAGE${NC} (This may take a while...)"
        docker pull $DOCKER_IMAGE > /dev/null 2>&1
    fi

    ### Check if hostapd is running in the host
    hostapd_pid=$(pgrep hostapd)
    if [ ! "$hostapd_pid" == "" ] 
    then
       echo -e "${BLUE}[INFO]${NC} hostapd is running"
       kill -9 "$hostapd_pid"
    else
        echo -e "${BLUE}[INFO]${NC} hostapd is stopped"
    fi

    # Unblock wifi and bring the wireless interface up
    echo -e "${BLUE}[INFO]${NC} Unblocking wifi and setting ${IFACE} up"
    rfkill unblock wifi
    ifconfig "$IFACE" up

    echo "[+] Adding natting rule to iptables (host)"
    iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    
    ### Enable IP forwarding
    echo "[+] Enabling IP forwarding (host)" 
    echo 1 > /proc/sys/net/ipv4/ip_forward

    ### Generating hostapd conf file
    echo -e "[+] Generating hostapd.conf"
    sed -e "s/_SSID/$SSID/g" -e "s/_IFACE/$IFACE/" -e "s/_CHANNEL/$CHANNEL/g" -e "s/_PASSPHRASE/$PASSPHRASE/g" "$PATHSCRIPT"/templates/hostapd.template > "$PATHSCRIPT"/hostapd.conf

    ### Generating dnsmasq conf file
    echo -e "[+] Generating dnsmasq.conf" 
    sed -e "s/_DNS_SERVER/$DNS_SERVER/g" -e "s/_IFACE/$IFACE/" -e "s/_SUBNET_FIRST/$SUBNET.20/g" -e "s/_SUBNET_END/$SUBNET.254/g" "$PATHSCRIPT"/templates/dnsmasq.template > "$PATHSCRIPT"/dnsmasq.conf
}

allocate_ifaces () {
    pid=$1

    # Assign phy wireless interface to the container 
    mkdir -p /var/run/netns
    ln -s /proc/"$pid"/ns/net /var/run/netns/"$pid"
    iw phy "$PHY" set netns "$pid"
    
    # The rest is necessary ONLY if using --net=none in docker:
    
    # Create a pair of "peer" interfaces veth0 and veth1,
    # bind the veth0 end to the bridge, and bring it up
    ip link add veth0 type veth peer name veth1
    brctl addif "$BRIDGE" veth0
    ip link set veth0 up
    # Place veth1 inside the container's network namespace,
    ip link set veth1 netns "$pid"
    ip netns exec "$pid" ip link set dev veth1 name eth0
    ip netns exec "$pid" ip link set eth0 address 12:34:56:78:9a:bc
    ip netns exec "$pid" ip link set eth0 up
    ip netns exec "$pid" ip addr add "$WAN_IP" dev eth0
    ip netns exec "$pid" ip route add default via "$GW"
}

service_start () { 
    IFACE="$1"
    echo -e "[+] Starting the docker container with name ${GREEN}$DOCKER_NAME${NC}"
    # docker run --rm -t -i --name $NAME --net=host --privileged -v $PATHSCRIPT/hostapd.conf:/etc/hostapd/hostapd.conf -v $PATHSCRIPT/dnsmasq.conf:/etc/dnsmasq.conf fgg89/ubuntu-ap /sbin/my_init -- bash -l
    docker run -d --name $DOCKER_NAME --net=none --privileged -v "$PATHSCRIPT"/hostapd.conf:/etc/hostapd/hostapd.conf -v "$PATHSCRIPT"/dnsmasq.conf:/etc/dnsmasq.conf $DOCKER_IMAGE /sbin/my_init > /dev/null 2>&1
    pid=$(docker inspect -f '{{.State.Pid}}' $DOCKER_NAME)
    # TODO: debug messages
	#echo -e "${BLUE}[INFO]${NC} $IFACE is now exclusively handled to the docker container"
    #echo -e "[+] Configuring wiring in the docker container and attaching its eth to the default docker bridge"
    # This is not necessary if --net=none is not used), however we'd still need to pass the wifi interface to the container
    allocate_ifaces "$pid"
    ### Assign an IP to the wifi interface
    echo -e "[+] Configuring ${GREEN}$IFACE${NC} with IP address ${GREEN}$IP_AP${NC}"
    ip netns exec "$pid" ip addr flush dev "$IFACE"
    ip netns exec "$pid" ip link set "$IFACE" up
    ip netns exec "$pid" ip addr add "$IP_AP$NETMASK" dev "$IFACE"

    ### iptables rules for NAT
    echo "[+] Adding natting rule to iptables (container)"
    ip netns exec "$pid" iptables -t nat -A POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE
    
    ### Enable IP forwarding
    echo "[+] Enabling IP forwarding (container)"
    ip netns exec "$pid" echo 1 > /proc/sys/net/ipv4/ip_forward
    ### start hostapd and dnsmasq in the container
    echo -e "[+] Starting ${GREEN}hostapd${NC} and ${GREEN}dnsmasq${NC} in the docker container ${GREEN}$DOCKER_NAME${NC}"
    docker exec "$DOCKER_NAME" start_ap
}

service_stop () { 
    IFACE="$1"
    echo -e "[-] Stopping ${GREEN}$DOCKER_NAME${NC}"
    docker stop $DOCKER_NAME > /dev/null 2>&1 
    echo -e "[-] Removing ${GREEN}$DOCKER_NAME${NC}"
    docker rm $DOCKER_NAME > /dev/null 2>&1 
    echo [-] Reversing iptables configuration
    iptables -t nat -D POSTROUTING -s $SUBNET.0$NETMASK ! -d $SUBNET.0$NETMASK -j MASQUERADE > /dev/null 2>&1
    #echo [-] Disabling ip forwarding
    #echo 0 > /proc/sys/net/ipv4/ip_forward
    echo [-] Removing conf files
    if [ -e "$PATHSCRIPT"/hostapd.conf ]
    then
        rm "$PATHSCRIPT"/hostapd.conf
    fi
    if [ -e "$PATHSCRIPT"/dnsmasq.conf ]
    then
        rm "$PATHSCRIPT"/dnsmasq.conf
    fi
    echo [-] Removing IP address in "$IFACE"
    ip addr del "$IP_AP$NETMASK" dev "$IFACE" > /dev/null 2>&1
}

if [ "$1" == "start" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting..."
        exit 1
    fi
    IFACE=${2}
    clear    
    print_banner
    init "$IFACE"
    service_start "$IFACE"
elif [ "$1" == "stop" ]
then
    if [[ -z "$2" ]]
    then
        echo -e "${RED}[ERROR]${NC} No interface provided. Exiting..."
        exit 1
    fi
    IFACE=${2}
    service_stop "$IFACE"
    # Clean up dangling symlinks in /var/run/netns
    find -L /var/run/netns -type l -delete
else
    echo "Usage: $0 <start|stop> <interface>"
fi
