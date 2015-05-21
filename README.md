# docker-ap

This script configures an Ubuntu-based system to act as a WiFi access point. The AP runs inside a docker container.

The script should be run as sudo. The first time the script is executed, it will pull the docker image from fgg89/ubuntu-ap repository. This docker image is based on baseimage (Please visit https://github.com/phusion/baseimage-docker for more info). The image contains the programs dnsmasq and hostapd. Their respective configuration files are generated on the fly and mounted in the docker container.

## Usage

```
./docker_ap.sh interface start|stop
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
wpa_passphrase=chooseastrongpassword
wpa_key_mgmt=WPA-PSK WPA-EAP

logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
```

The ssid, wpa_passphrase, interface and subnetwork are initially hardcoded as variables in the script.
