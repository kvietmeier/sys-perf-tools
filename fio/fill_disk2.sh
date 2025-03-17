#!/bin/bash

# List of drives (space-separated)
DRIVES="/dev/nvme0n11 /dev/nvme0n12 /dev/nvme0n13 /dev/nvme0n14 /dev/nvme0n15 \
        /dev/nvme0n16 /dev/nvme0n17 /dev/nvme0n18 /dev/nvme0n19 /dev/nvme0n20 \
        /dev/nvme0n21 /dev/nvme0n22 /dev/nvme0n23 /dev/nvme0n24 /dev/nvme0n25 \
        /dev/nvme0n26 /dev/nvme0n27 /dev/nvme0n28 /dev/nvme0n29 /dev/nvme0n30 \
        /dev/nvme0n26 /dev/nvme0n27"

# Create FIO job file
JOB_FILE="fill_multi_drives.fio"

# Start with an empty file
> "$JOB_FILE"

# Loop through drives and create a job section for each
for DRIVE in $DRIVES; do
  cat <<EOF >> "$JOB_FILE"
[fill_disk_${DRIVE##*/}]
filename=$DRIVE
filesize=4400G
ioengine=libaio
direct=1
verify=0
randrepeat=0
bs=128K
iodepth=64
rw=randwrite
iodepth_batch_submit=64
iodepth_batch_complete_max=64

EOF
done

echo "Generated FIO job file: $JOB_FILE"
cat "$JOB_FILE"

# Run the generated FIO job
sudo fio "$JOB_FILE"

