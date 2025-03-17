#!/bin/bash
# Using a list of SSDs, create job files to run latency tests on all of them.


# Configurable Parameters for job file
DRIVE_LIST_FILE="drive_list.txt"  # File containing the list of drives
SIZE="1G"
RUNTIME="600"
BS="4k"
RW="randrw"
RWMIXREAD="70"                          # Larger = more read
NUMJOBS="7"
LOG_DIR="../logs"
BASE_JOB_FILE="fio_latency_job_file"

# Ensure log directory exists
if [[ ! -d "$LOG_DIR" ]]; then
    echo "Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
else
    echo "Log directory already exists: $LOG_DIR"
fi

# Function to generate FIO job file
generate_job_file() {
    local drive="$1"
    local job_file="${BASE_JOB_FILE}_$(basename "$drive").ini"
    
    # Check if job file exists
    if [[ -f "$job_file" ]]; then
        read -p "$job_file already exists. Overwrite? (y/n): " confirm
        if [[ "$confirm" != "y" ]]; then
            echo "Skipping $job_file..."
            return
        fi
    fi

    # Create the job file
    cat << EOF > "$job_file"
[global]
filename=$drive
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
EOF

    # Generate individual test sections
    for QD in 1 2 4 8 16 32 64; do
        LOG_FILE="$LOG_DIR/ssd_lat_test_lat_qd_${QD}_$(basename "$drive")"
        
        # Check if log file exists
        if [[ -f "$LOG_FILE" ]]; then
            read -p "$LOG_FILE already exists. Overwrite? (y/n): " confirm
            if [[ "$confirm" != "y" ]]; then
                echo "Skipping QD $QD for $drive..."
                continue
            fi
        fi
        
cat << EOF >> "$job_file"

[lat_test_qd_$QD]
iodepth=$QD
write_lat_log=$LOG_FILE
EOF
    done

    echo "FIO job file generated: $job_file"

    # Optionally run the test in the background
    echo "Starting FIO test on $drive..."
    #fio "$job_file" &
}  ###--- End Function


# Read the list of drives from the file and loop through each one
if [[ -f "$DRIVE_LIST_FILE" ]]; then
    while IFS= read -r DRIVE; do
        # Skip empty lines and comment lines (starting with #)
        if [[ -z "$DRIVE" || "$DRIVE" =~ ^# ]]; then
            continue
        fi

        if [[ -b "$DRIVE" ]]; then
            generate_job_file "$DRIVE"
        else
            echo "Warning: $DRIVE is not a valid block device. Skipping..."
        fi
    done < "$DRIVE_LIST_FILE"
else
    echo "Error: $DRIVE_LIST_FILE does not exist. Exiting."
    exit 1
fi

# Wait for all background jobs to finish
#wait

echo "All FIO tests completed."
