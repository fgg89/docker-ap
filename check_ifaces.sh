#!/bin/bash

cnt=0
IFS=$'\n'
ifaces=($(ifconfig -a | sed 's/[ \t].*//;/^$/d'))

for i in "${ifaces[@]}"
do
  if [ ${i:0:4} == "wlan" ]
  then
    wifaces[$cnt]=$i
    cnt=$((cnt+1))
  fi
done

#number_wifaces=${#wifaces[@]}
number_wifaces=$cnt
echo "Interfaces available: ${wifaces[@]}"
echo "Please select an interface:"
select option in ${wifaces[@]}
do
  # To be improved...
  case $option in
  wlan* ) IFACE=$option && echo "Interface $option selected";;
  * ) echo Invalid option;;
  esac
done
