#!/bin/bash
### Wrapper to run FIO in the background against a bunch of drives.

# List of drives to test (update as needed)
DRIVES=(/dev/nvme0n3 /dev/nvme0n4 /dev/nvme0n5 /dev/nvme0n6 /dev/nvme0n7 /dev/nvme0n8 /dev/nvme0n9 /dev/nvme0n10)

# Path to the existing FIO job file
FIO_JOB_TEMPLATE="./fill_disk.fio"

# Run FIO on each drive in the background
for DRIVE in "${DRIVES[@]}"; do
  JOB_FILE="fio_${DRIVE##*/}.fio"
  
  # Replace the filename in the existing job file
  sed "s|filename=.*|filename=$DRIVE|" "$FIO_JOB_TEMPLATE" > "$JOB_FILE"
  
  echo "Starting FIO on $DRIVE..."
  sudo fio "$JOB_FILE" > "fio_${DRIVE##*/}.log" 2>&1 &
  
  sleep 5 # Small delay to prevent overwhelming the system
done

echo "All FIO jobs started in the background."

# Optionally: Wait for all background jobs to finish
wait

echo "All FIO jobs completed."

