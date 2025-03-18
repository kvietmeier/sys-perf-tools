#!/bin/bash
###=================================================================================###
#
#   Run individual job files to gather json output from latency runs
#
#   This script will outout both a standard .csv log and reformat stdout to json.
#
###=================================================================================###

# Define the list of iodepths you want to test
iodepths=(1 2 4 8 16 32 64)

# Test parameters
filename="/dev/nvme0n9"
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

drive=${filename##*/}

# Loop through each iodepth and run the test
for iodepth in "${iodepths[@]}"; do
  # Run the fio job for the current iodepth
  sudo fio --name=lat_test_qd_${iodepth} \
      --filename=$filename \
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
      --write_lat_log=logs/${drive}-qd-${iodepth} \
      --output-format=json > ./logs/${drive}-qd-${iodepth}.json
done
