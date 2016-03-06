# docker-ap

This script configures a Debian-based system to act as a wireless access point. The whole AP functionality runs inside a docker container.

The script should be run as sudo. The docker image ``fgg89/docker-ap`` will be built if it will not be found in the system. The docker image is based on baseimage (Please visit https://github.com/phusion/baseimage-docker for more info). The image contains the programs dnsmasq and hostapd. Their respective configuration files are generated on the fly and mounted in the docker container.

The docker container has exclusive access to the physical wireless interface (for more info please visit: https://github.com/fgg89/docker-ap/wiki/Container-access-to-wireless-network-interface)

Tested on: Ubuntu 14.04 LTS, Raspbian 8 (jessie)
Supported architectures: x86_64, armv7

Default configuration
---------------------

* SSID = **DockerAP**
* Passphrase = **dockerap123**

## Usage

Start the service:

```
./docker_ap start [wlan_interface]
```

Stop the service:

```
./docker_ap stop [wlan_interface]
```


