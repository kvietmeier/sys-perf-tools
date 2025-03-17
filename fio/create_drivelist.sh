#!/bin/bash

# Get a list of the Managed disks
drives=$(nvme list | egrep -v -w '0x1|Node|^-' | awk '{print $1}' | sort -V)
echo "$drives" | tr ' ' '\n' > ./drive_list.txt
