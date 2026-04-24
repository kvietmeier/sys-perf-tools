#!/bin/bash

for i in $(ls -l /dev/disk/by-path | egrep pci | grep -v part | awk '{print substr($11, 7)}' | sort)
  do 
      sudo sdparm --get=WCE /dev/${i}
  done
