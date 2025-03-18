#!/bin/bash
###==============================================================================###
#   Created by:
#      Karl Vietmeier
#      VAST Data Cloud Solutions Architect
#   
#   Purpose:
#    From a file with a list of drives, create a job file to concurrently fill all
#    of them with "0s", effectively zeroing out the drive.
#
#   NOTES: 
#     * Important for testing SSDs.
#     * Dynamically calculate filesize
#     * Error handling for empty drive list and missing size file
#
###==============================================================================###

# Create the drive list file
# WARNING - Ensure this line is correct for your system:
# We exclude "0x1" to avoid wiping the boot drive.
drives=$(nvme list | egrep -v -w '0x1|Node|^-' | awk '{print $1}' | sort -V)
if [[ -z "$drives" ]]; then
  echo "No drives found. Exiting."
  exit 1
fi

echo "$drives" | tr ' ' '\n' > ./nvme_drive_list.txt

# File containing the list of drives (one drive per line)
DRIVE_LIST="./nvme_drive_list.txt"

# Create FIO job file
JOB_FILE="./jobs/zero_out_drives.ini"

# Start with an empty job file
> "$JOB_FILE"

# Write the global section
cat <<EOF > "$JOB_FILE"
[global]
ioengine=libaio
direct=1
verify=0
randrepeat=0
bs=128K
iodepth=64
iodepth_batch_submit=64
iodepth_batch_complete_max=64
rw=randwrite

EOF

# Read the drives from the file and create a job section for each
while IFS= read -r DRIVE; do
  SSD=${DRIVE##*/}
  
  # Validate if the size file exists to avoid errors
  if [[ -e "/sys/block/${SSD}/size" ]]; then
    SIZE=$(( $(cat /sys/block/${SSD}/size) * 512 ))
    
    # Create the job file
    cat <<EOF >> "$JOB_FILE"
[fill_disk_${SSD}]
filename=$DRIVE
filesize=$SIZE

EOF

    echo "Added drive: $SSD with size: $SIZE bytes"
  else
    echo "Skipping $SSD (size file not found)"
  fi

done < "$DRIVE_LIST"

echo "Generated FIO job file: $JOB_FILE"
cat "$JOB_FILE"

# Uncomment to run the generated FIO job file in parallel
#sudo fio "$JOB_FILE"