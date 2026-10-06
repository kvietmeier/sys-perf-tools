#!/bin/bash
###======================================= dool_capture.sh ==================================================### 
#  Run dool and collect output into csv files.
#  Collect system profile, summarizing system state
#  
#  Optimized for collretion IO stats on data drives for Minio/Ceph, etc.
#   - Identifies SSD vs HDD
#
#  Has hard coded ethernet interfaces - too many.
###==========================================================================================================### 

###--- Configure Output files
CURRENT_TIME=$(date +%m%d:%H%M)
OUTPUTDIR=${HOME}/dool/

# Check if the directory for output exists
if [ ! -d $OUTPUTDIR ] ; then
  mkdir $OUTPUTDIR 2> /dev/null
fi

OUTPUTFILE_proc=${OUTPUTDIR}dool_process.${CURRENT_TIME}.csv
OUTPUTFILE_io=${OUTPUTDIR}dool_io.${CURRENT_TIME}.csv
OUTPUTFILE_sys=${OUTPUTDIR}dool_sys.${CURRENT_TIME}.csv


###-- Variables/Setup
HDD=()
SSD=()
pcidev=$(lspci | egrep 'SATA|SAS' | grep LSI | awk '{print $1}')
drives=($(ls -l /dev/disk/by-path | egrep $pcidev | awk '{print substr($11, 7)}' | sort))

# Loop through array:
#   Check each drive to see if it is an SSD or HDD then populate HDD and SSD appropriately
for drive in "${drives[@]}" ; do
  type=$(cat /sys/block/${drive}/queue/rotational)
  if [ $type == 1 ] ; then
    HDD[${#HDD[*]}]=$drive
  elif [ $type == 0 ] ; then
    SSD[${#SSD[*]}]=$drive
  fi
  #echo "$drive = $type"
done

# Convert array to string for commands
hdd=$(IFS=,; echo "${HDD[*]}")

# Command intervals (s)short, (m)edium, (l)ong, (ll)onger
sinterval=1
minterval=10
linterval=30
llinterval=3600

# Duration
count=380

# Construct dool commamds
dool_io_flags="-D total,$hdd -N bond0,bond1"
dool_proc_flags="--time -p -c --disk --mem --top-cpu --top-bio --top-latency "
dool_sys_flags="--time --load --proc --cpu --sys --vm --disk  --net -N eth0,eth1,eth2,eth3,eth4,eth5,eth6,eth7,bond0,bond1"

# dool command line
dool_io="dool $dool_io_flags --output $OUTPUTFILE_io $sinterval $count"
dool_process="dool $dool_proc_flags --output $OUTPUTFILE_proc $sinterval $count"
dool_sys="dool $dool_sys_flags --output $OUTPUTFILE_sys $sinterval $count"


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
