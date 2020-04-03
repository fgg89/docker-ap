# README

This script configures a Debian-based system to act as a wireless access point. The whole AP functionality runs inside a docker container.

The script must be run as ``root`` and be given execution permissions:

```
# chmod u+x docker_ap
```

The docker image ``fgg89/docker-ap`` will be built the first time the script is executed (you can find the Dockerfile under ``/build``). The image contains all the necessary dependencies, including dnsmasq and hostapd. Their respective configuration files are generated on the fly and mounted into the container.

The docker container is granted exclusive access to the physical wireless interface (for more info please visit: https://github.com/fgg89/docker-ap/wiki/Container-access-to-wireless-network-interface)

* Tested on: Ubuntu 14.04 LTS/16.04 LTS/18.04 LTS and Raspbian 8 (Jessie)
* Supported architectures: x86_64, armv7

Default configuration is specified in ``wlan_config.txt``:

* SSID = **DockerAP**
* PASSPHRASE = **dockerap123**
* HW_MODE=g
* CHANNEL=1

## Usage

Start the service:

```
# docker_ap start [wlan_interface]
```

Stop the service:

```
# docker_ap stop [wlan_interface]
```

### Donate

[![paypal](https://www.paypalobjects.com/en_US/ES/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CGSJNMMTF7EC8)

