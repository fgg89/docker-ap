# docker-ap

This script configures an Ubuntu-based system to act as a WiFi access point. The AP runs inside a docker container.

The script should be run as sudo. The first time the script is run, it will pull the docker image from fgg89/ubuntu-ap repository. This docker image is based on baseimage (Please visit https://github.com/phusion/baseimage-docker for more info). The image contains dnsmasq and hostapd. 

dnsmasq configuration
=====================

```
no-resolv
server=8.8.8.8
interface=lo,wlan5
no-dhcp-interface=lo
dhcp-range=192.168.7.20,192.168.7.254,255.255.255.0,12h
```

hostapd configuration
=====================

```
sid=DockerAP
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

NOTE: In this case, wlan5 is the WiFi interface to be used.
