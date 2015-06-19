#!/bin/bash


if [ "$#" -ne 0 ]; then
    echo "Usage: deallocate-ifaces.sh"
    exit 1
fi

# When you finally exit the shell and Docker cleans up the container, the network namespace is destroyed along with our virtual eth0 — whose destruction in turn destroys interface A out in the Docker host and automatically un-registers it from the docker0 bridge. So everything gets cleaned up without our having to run any extra commands! Well, almost everything:

# Clean up dangling symlinks in /var/run/netns

find -L /var/run/netns -type l -delete
