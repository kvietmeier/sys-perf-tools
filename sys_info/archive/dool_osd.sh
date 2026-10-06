#!/bin/bash
###======================================= dool_osd.sh =====================================================### 
###  Basic Usage: Run dool and collect output into csv files.
###  Collect system profile while monitoring disk usage during benchmark runs or performance troubleshooting
###  Created By:   Karl Vietmeier
###                Technical Leader, Cloud Engineering Cisco System
###
###  To Do:
###        Prompt for output directory
###        Prompt for duration
###==========================================================================================================### 

###--- Configure output
CURRENT_TIME=$(date +%m%d:%H%M)
OUTPUTDIR=${HOME}/dool/

OUTPUTFILE_proc=${OUTPUTDIR}dool_process.${CURRENT_TIME}.csv
OUTPUTFILE_io=${OUTPUTDIR}dool_io.${CURRENT_TIME}.csv
OUTPUTFILE_sys=${OUTPUTDIR}dool_sys.${CURRENT_TIME}.csv

# Check if the directory for output exists
if [ ! -d $OUTPUTDIR ] ; then
  mkdir $OUTPUTDIR 2> /dev/null
fi


###--- Variables/Setup
# Empty Arrays
HDD=()
SSD=()

# Collect the disk devices to run dool against
pcidev=$(lspci | egrep 'SATA|SAS' | grep LSI | awk '{print $1}')
drives=($(ls -l /dev/disk/by-path | egrep $pcidev | grep -v part | awk '{print substr($11, 7)}' | sort))

# Loop through array and check each drive to see if it is an SSD or HDD then populate
# HDD and SSD apprpriately - Ceph cluster with SSD cache drives and HDD OSD
for drive in "${drives[@]}"
do
     type=$(cat /sys/block/${drive}/queue/rotational)
     if [ $type == 1 ]
        then
            HDD[${#HDD[*]}]=$drive
     elif [ $type == 0 ]
        then
            SSD[${#SSD[*]}]=$drive
     fi
     #echo "$drive = $type"
done

hdd=$(IFS=,; echo "${HDD[*]}")

# Command delays
sdelay=1
mdelay=10
ldelay=30
lldelay=3600
count=50000

dool_io_flags="-D total,$hdd -N bond0,bond1"
dool_proc_flags="--time -p -c --disk --mem --top-cpu --top-bio --top-latency "
dool_sys_flags="--time --load --proc --cpu --sys --vm --disk  --net -N bond0,bond1"

#dool_disk="dool $dool_disk_flags $ldelay $count"
dool_io="dool $dool_io_flags --output $OUTPUTFILE_io $mdelay $count"
dool_process="dool $dool_proc_flags --output $OUTPUTFILE_proc $mdelay $count"
dool_sys="dool $dool_sys_flags --output $OUTPUTFILE_sys $mdelay $count"



###-- Functions
# Run dool in background
bkground_dool () {
  run_dool="$@"
  ${run_dool} &>/dev/null &
  disown
}

#-- End Functions


###-- Main - run dool in background
bkground_dool ${dool_process}
bkground_dool ${dool_io}
bkground_dool ${dool_sys}
