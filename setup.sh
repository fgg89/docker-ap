#!/bin/bash

apt-get update
apt-get install wget bridge-utils

# Get the latest Docker package
wget -qO- https://get.docker.com/ | sh


