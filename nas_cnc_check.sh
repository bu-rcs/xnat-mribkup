#!/bin/bash


## script to get nas storage usage and plot it

# Get disk usage
usage=`df -h /data-ro_1 | column -t`
date=`date -I`

# Print to nas_check.log
total=`echo $usage | awk '{print $9}'`
current=`echo $usage | awk '{print $10}'`
avail=`echo $usage | awk '{print $11}'`
perc=`echo $usage | awk '{print $12}'`
echo $date $current $avail $perc $total >> CILSE-CNC

echo "USAGE: "$current "/" $total
echo "USAGE: "$perc 
echo "DATE:" $date
