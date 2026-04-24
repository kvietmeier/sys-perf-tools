#!/bin/bash
echo "###---  SSD Info "

# Header with fixed-width columns
printf "%-8s %-4s %-12s %-31s %-8s\n" "DEVICE" "WCE" "VENDOR" "MODEL" "SIZE"

for i in $(ls -l /dev/disk/by-path | grep pci | grep -v part | awk '{print substr($11, 7)}' | sort); do
  device="/dev/$i"

  # Get WCE (Write Cache Enable)
  wce=$(sudo sdparm --get=WCE "$device" 2>/dev/null | awk '/WCE/ {print $NF}')

  # Get Vendor and Model
  read vendor model <<<$(udevadm info --query=all --name="$device" | awk -F'=' '/ID_VENDOR=|ID_MODEL=/{print $2}' | xargs)

  # Get Size (in human-readable format)
  size=$(lsblk -dn -o SIZE "$device")

  # Output aligned row
  printf "%-8s %-4s %-12s %-30s %-8s\n" "$i" "$wce" "$vendor" "$model" "$size"
done

echo ""