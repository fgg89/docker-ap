# docker-ap

This script configures an Ubuntu-based system to act as a wireless access point. The AP runs inside a docker container.

The script should be run as sudo. The first time the script is executed, it will pull the docker image from fgg89/ubuntu-ap repository. This docker image is based on baseimage (Please visit https://github.com/phusion/baseimage-docker for more info). The image contains the programs dnsmasq and hostapd. Their respective configuration files are generated on the fly and mounted in the docker container.

The docker container has exclusive access to the physical wireless interface (for more info please visit: https://github.com/fgg89/docker-ap/wiki/Container-access-to-wireless-network-interface)

Default configuration
---------------------

SSID = **DockerAP**
passphrase = **dockerap123**

## Usage

```
./docker_ap.sh interface <start|stop> [wlan_interface]
```

If no wlan interface is specified, it will use wlan5 by default.

It is recommended to stop the service with the script in order to revert the host configuration to its initial state (iptables, ip forwarding, etc).

You can get into the container once it's been run by using the ``exec`` option in docker:

```
docker exec -it ap-container bash
```

## Example of configuration files

### dnsmasq configuration

```
no-resolv
server=8.8.8.8
interface=lo,wlan5
no-dhcp-interface=lo
dhcp-range=192.168.7.20,192.168.7.254,255.255.255.0,12h
```

### hostapd configuration

```
ssid=DockerAP
interface=wlan5
hw_mode=g
channel=1

wpa=2
wpa_passphrase=dockerap123
wpa_key_mgmt=WPA-PSK WPA-EAP

logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
```

The ssid, wpa_passphrase, interface and subnetwork are initially hardcoded as variables in the script.
