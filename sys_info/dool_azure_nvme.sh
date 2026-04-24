#!/usr/bin/bash
###==========================================================================================================###
#
#    Basic Usage: Run dool and collect output into csv files.
#    Collect system profile while monitoring disk usage during benchmark runs or performance troubleshooting
#    Created By:   Karl Vietmeier
#                  Cloud Solutions Architect, Intel
#
#    Written for an Azure Ubuntu VM with NVME controllers
#
###==========================================================================================================###

###-- Variables/Setup

# Enumerate the nvme drives
nvme_drives=($(ls -l /dev/disk/by-path | grep nvme | grep -v part | awk '{print substr($11, 7)}' | sort))
disks=$(IFS=,; echo "${nvme_drives[*]}")

# Command intervals (s)short, (m)edium, (l)ong, (ll)onger
sinterval=1
minterval=10
linterval=30
llinterval=3600

# Duration
count=380

# dool flags
dool_io_flags="-D total,$disks -N eth0"
dool_proc_flags="--time -p -c --disk --mem --top-cpu --top-bio --top-latency "
dool_sys_flags="--time --load --proc --cpu --sys --vm --disk  --net -N eth0"

# Setup directories/output files
CURRENT_TIME=$(date +%m%d:%H%M)
OUTPUTDIR=${HOME}/dool/

# Check if the directory for output exists
if [ ! -d $OUTPUTDIR ] ; then
  mkdir $OUTPUTDIR 2> /dev/null
fi

OUTPUTFILE_proc=${OUTPUTDIR}dool_process.${CURRENT_TIME}.csv
OUTPUTFILE_io=${OUTPUTDIR}dool_io.${CURRENT_TIME}.csv
OUTPUTFILE_sys=${OUTPUTDIR}dool_sys.${CURRENT_TIME}.csv

### Run dool
# dool command line
dool_io="dool $dool_io_flags --output $OUTPUTFILE_io $linterval $count"
dool_process="dool $dool_proc_flags --output $OUTPUTFILE_proc $linterval $count"
dool_sys="dool $dool_sys_flags --output $OUTPUTFILE_sys $linterval $count"


###-- Functions
# Run dool in background
bkground_dool () {
  run_dool="$@"
  ${run_dool} &>/dev/null &
  disown
}

#-- End Functions

###-- Main 
bkground_dool ${dool_process}
bkground_dool ${dool_io}
bkground_dool ${dool_sys}


