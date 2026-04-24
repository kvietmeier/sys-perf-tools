#!/bin/bash
###============================================= dool.sh ====================================================### 
#  Run dool and collect output into csv files.
#  Collect system profile, summarizing system state
#
#  Basic dool commands
#
###==========================================================================================================### 

###--- Configure output

CURRENT_TIME=$(date +%m%d:%H%M)
OUTPUTDIR=${HOME}/dool/
OUTPUTFILE_proc=${OUTPUTDIR}dool_process.${CURRENT_TIME}.csv
OUTPUTFILE_sys=${OUTPUTDIR}dool_sys.${CURRENT_TIME}.csv

# Check if the directory for output exists
if [ ! -d $OUTPUTDIR ] ; then
  mkdir $OUTPUTDIR 2> /dev/null
fi

###--- Variables

# Command intervals

sinterval=1
minterval=10
linterval=30
llinterval=3600

count=380

dool_proc_flags="--time -p -c --disk --mem --top-cpu --top-bio --top-latency "
dool_sys_flags="--time --load --proc --cpu --sys --vm --disk  --net -N bond0,bond1"

dool_process="dool $dool_proc_flags --output $OUTPUTFILE_PROC $linterval $count"
dool_sys="dool $dool_sys_flags --output $OUTPUTFILE_SYS $linterval $count"



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
bkground_dool ${dool_sys}
