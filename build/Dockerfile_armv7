# Use phusion/baseimage as base image. To make your builds
# reproducible, make sure you lock down to a specific version, not
# to `latest`! See
# https://github.com/phusion/baseimage-docker/blob/master/Changelog.md
# for a list of version numbers.
FROM armv7/armhf-baseimage:latest
MAINTAINER fgg89

# Use baseimage-docker's init system.
CMD ["/bin/bash"]

# Update the repos
RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y hostapd dnsmasq 
RUN echo "#!/bin/bash\n### START dnsmasq\nservice dnsmasq start > /dev/null 2>&1\n### START hostapd\nservice hostapd start > /dev/null 2>&1" > /usr/bin/start_ap
RUN echo "RUN_DAEMON=\"yes\"\nDAEMON_CONF=\"/etc/hostapd/hostapd.conf\"" >> /etc/default/hostapd
RUN chmod u+x /usr/bin/start_ap

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
