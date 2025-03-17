#!/bin/bash
###==============================================================================###
#  From a file with a list of drives create a job file to concurrently fill all
#  them with "0s", effectively zero-ing the out the drive
#
#  Important for testing SSD
#
###==============================================================================###

# File containing the list of drives (one drive per line)
DRIVE_LIST="./drive_list.txt"

# Create FIO job file
JOB_FILE="./zero_out_drives.ini"

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
filesize=4400G
iodepth=64
iodepth_batch_submit=64
iodepth_batch_complete_max=64
rw=randwrite

EOF

# Read the drives from the file and create a job section for each
while IFS= read -r DRIVE; do
  cat <<EOF >> "$JOB_FILE"
[fill_disk_${DRIVE##*/}]
filename=$DRIVE

EOF
done < "$DRIVE_LIST"

echo "Generated FIO job file: $JOB_FILE"
cat "$JOB_FILE"

# Run the generated FIO job file in parallel
#sudo fio "$JOB_FILE"
