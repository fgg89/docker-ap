#!/bin/bash
#title           :deallocate_ifaces.sh
#description     :This script will complete the cleaning after destroying the container.
#author          :Fran Gonzalez
#date            :20150619
#version         :0.1    
#usage           :bash deallocate_ifaces.sh 
#bash_version    :
#==============================================================================all

if [ "$#" -ne 0 ]; then
    echo "Usage: $0"
    exit 1
fi

# When you finally exit the shell and Docker cleans up the container, the network namespace is destroyed along with our virtual eth0 — whose destruction in turn destroys interface A out in the Docker host and automatically un-registers it from the docker0 bridge. So everything gets cleaned up without our having to run any extra commands! Well, almost everything:

# Clean up dangling symlinks in /var/run/netns

find -L /var/run/netns -type l -delete
