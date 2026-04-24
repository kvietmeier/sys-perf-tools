#!/bin/bash

TIMEOUT=2

echo "Detecting environment..."

# ---- WSL CHECK ----
if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
    echo "Environment: Windows Subsystem for Linux (WSL)"

    # Try to determine WSL version
    if grep -qi "microsoft-standard" /proc/version; then
        echo "WSL Version: WSL2"
    else
        echo "WSL Version: WSL1"
    fi

    uname -a
    exit 0
fi


# ---- AZURE CHECK ----
if curl -s --max-time $TIMEOUT -f -H Metadata:true \
   "http://169.254.169.254/metadata/instance?api-version=2021-02-01" > /dev/null 2>&1
then
    echo "Cloud Provider: AZURE"

    LOCATION=$(curl -s -H Metadata:true \
      "http://169.254.169.254/metadata/instance/compute/location?api-version=2021-02-01&format=text")

    VMID=$(curl -s -H Metadata:true \
      "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2021-02-01&format=text")

    echo "Region: $LOCATION"
    echo "VM ID: $VMID"
    exit 0
fi


# ---- GCP CHECK ----
if curl -s --max-time $TIMEOUT -f -H "Metadata-Flavor: Google" \
   "http://169.254.169.254/computeMetadata/v1/" > /dev/null 2>&1
then
    echo "Cloud Provider: GCP"

    ZONE=$(curl -s -H "Metadata-Flavor: Google" \
      "http://169.254.169.254/computeMetadata/v1/instance/zone")

    HOSTNAME=$(curl -s -H "Metadata-Flavor: Google" \
      "http://169.254.169.254/computeMetadata/v1/instance/hostname")

    echo "Zone: $ZONE"
    echo "Hostname: $HOSTNAME"
    exit 0
fi


# ---- AWS CHECK ----
if curl -s --max-time $TIMEOUT -f \
   "http://169.254.169.254/latest/meta-data/" > /dev/null 2>&1
then
    echo "Cloud Provider: AWS"

    REGION=$(curl -s \
      http://169.254.169.254/latest/meta-data/placement/region)

    INSTANCE_ID=$(curl -s \
      http://169.254.169.254/latest/meta-data/instance-id)

    echo "Region: $REGION"
    echo "Instance ID: $INSTANCE_ID"
    exit 0
fi


# ---- FALLBACK ----
echo "Environment: On-Prem or Unknown Cloud"
echo "No Azure, GCP, AWS, or WSL metadata detected."
exit 1
