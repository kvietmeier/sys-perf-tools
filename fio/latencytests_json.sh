#!/bin/bash
###=================================================================================###
#
#   Created by:
#      Karl Vietmeier
#      VAST Data Cloud Solutions Architect
#   
#   Purpose:
#     Create individual FIO commands to gather latency statistics for attached drives.
#      - JSON outout only works on individual jobs, you can't output the sandard logs to json
#        so you need to generate a job for every queue depth.
#
#   Notes:
#   * This script will output both a standard .csv log and reformat stdout to json.
#   * You could create job files and run them but this seems cleaner.
#
###=================================================================================###

# Define the list of iodepths you want to test:
iodepths=(1 2 4 8 16 32 64)

# FIO Test parameters:
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

# Loop through each iodepth, create the commamd and run the test
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
