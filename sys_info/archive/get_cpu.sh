#!/usr/bin/bash
# Get CPU type from hosts
# 
#!/bin/bash

USER="labuser"
HOST_PREFIX="linux0"
HOST_COUNT=6

for i in $(seq 1 $HOST_COUNT); do
  HOST="${HOST_PREFIX}${i}"
  
  cpu=$(ssh "${USER}@${HOST}" \
    "grep -m2 'model name' /proc/cpuinfo | sed -E 's/.*: //' | tr '\n' ':'")
  
  echo "${HOST}:  ${cpu}"
done
