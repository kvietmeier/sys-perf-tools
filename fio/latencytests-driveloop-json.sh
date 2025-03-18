#!/bin/bash
###==============================================================================###
#  Test multiple drives with varying iodepth values using fio
###==============================================================================###

# Define the list of iodepths you want to test
iodepths=(1 2 4 8 16 32 64)

# Define the list of drives to test
drives=(/dev/nvme0n1 /dev/nvme0n2 /dev/nvme0n3)

# Test parameters
ioengine="libaio"
direct="1"
size="1G"
rtime="1800"
tbased="1"
bs="4k"
rw="randrw"
mix="70"
jobs="1"
group="1"
log_avg="1000"

# Loop through each drive
for drive in "${drives[@]}"; do
  drive_name=${drive##*/}

  # Loop through each iodepth and run the test
  for iodepth in "${iodepths[@]}"; do
    echo "Running test on $drive with iodepth=$iodepth"

    sudo fio --name=lat_test_${drive_name}_qd_${iodepth} \
        --filename=$drive \
        --ioengine=$ioengine \
        --direct=$direct \
        --size=$size \
        --runtime=$rtime \
        --time_based=$tbased \
        --bs=$bs \
        --rw=$rw \
        --rwmixread=$mix \
        --numjobs=$jobs \
        --group_reporting=$group \
        --log_avg_msec=$log_avg \
        --iodepth=${iodepth} \
        --write_lat_log=logs/${drive_name}_latency_qd_${iodepth} \
        --output-format=json > ./logs/${drive_name}_output_qd_${iodepth}.json

    echo "Test complete for $drive with iodepth=$iodepth"
  done
done

echo "All tests completed."
