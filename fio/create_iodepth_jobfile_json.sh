#!/bin/bash
###==============================================================================###
#   Create an FIO jobfile for a range of iodepths.
#   - Combine into one logfile - output in json
###==============================================================================###

# Configurable Parameters
FILENAME="/dev/nvme0n2"
SIZE="1G"
RUNTIME="600"
BS="4k"
RW="randrw"
RWMIXREAD="70"
NUMJOBS="7"
LOG_DIR="../logs"
JOB_FILE="../jobs/fio_growingiodepth_job.ini"

# Check if log directory exists - create if it doesn't otherwise keep going
if [[ ! -d "$LOG_DIR" ]]; then
    echo "Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
else
    echo "Log directory already exists: $LOG_DIR"
fi

# Check if job file exists
if [[ -f "$JOB_FILE" ]]; then
    read -p "$JOB_FILE already exists. Overwrite? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Generate the job file
cat << EOF > "$JOB_FILE"
# Evaluate latency at different iodepths 
[global]
filename=$FILENAME
ioengine=libaio
direct=1
size=$SIZE
runtime=$RUNTIME
time_based=1
bs=$BS
rw=$RW
rwmixread=$RWMIXREAD
numjobs=$NUMJOBS
group_reporting=1
log_avg_msec=1000
# Output in JSON format for easier parsing - need to use --output-format=json on cli
write_lat_log=$LOG_DIR/ssd_lat_combined_log.json
EOF

# Generate individual test sections for each iodepth, but use the same log file for all
for QD in 1 2 4 8 16 32 64; do
cat << EOF >> "$JOB_FILE"

[lat_test_qd_$QD]
iodepth=$QD
EOF
done

echo "FIO job file generated: $JOB_FILE"

# Optionally run the test
# Uncomment the next line to execute the job file directly
# fio "$JOB_FILE"
