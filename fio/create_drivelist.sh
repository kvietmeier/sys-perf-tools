#!/bin/bash
###=================================================================================###
#   Created by:
#      Karl Vietmeier
#      VAST Data Cloud Solutions Architect
#   
#   Purpose:
#     Get a list of the NVME connected drives
###=================================================================================###

# Prety simple - used in other scripts - here for reference.
drives=$(nvme list | egrep -v -w '0x1|Node|^-' | awk '{print $1}' | sort -V)
echo "$drives" | tr ' ' '\n' > ./drive_list.txt
