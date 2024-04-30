#!/bin/bash

# Get current date and time
date=$(date +"%Y-%m-%d_%H-%M-%S")

# Replace spaces with underscores in the date
date=${date// /_}

# Define the log file name
logfile="tarlog-${date}.txt"

# Open log file for writing
logfilepath="/cnc/LOGS/$logfile"
touch "$logfilepath"

# Define base directory
base="/cnc/DATA/INVESTIGATORS"

# Find directories older than 14 days within the base directory
OLD=$(find "$base" -mindepth 2 -maxdepth 2 -mtime +14 -type d)

#######################################################################
    # THIS IS FOR TESTING.
    # COMMENT OUT TO RUN FULLY. 
    # Only Look in MCMAINS.
#base="/cnc/DATA/INVESTIGATORS/INVESTIGATORS_MCMAINS"
#OLD=$(find "$base" -mindepth 1 -maxdepth 1 -mtime +14 -type d)
#######################################################################

# Count the number of directories found
numdir=$(echo "$OLD" | wc -l)
echo "$numdir directories to process" &>> "$logfilepath"

# Loop through each directory
while IFS= read -r dir; do
    # Get original DICOM count in the directory
    origcount=$(find "$dir" | wc -l)

    # Print DICOM count for study.
    echo "$origcount DICOMS to be processed" &>> "$logfilepath"
    
    # Define tar and gzipped tar file paths
    tarfile="${dir}.tar"
    ziptar="${tarfile}.gz"

    # Check if tarfile or gzipped tarfile already exist
    if [[ ! -e "$ziptar" && ! -e "$tarfile" ]]; then
        fulldir="$dir"

        # Print commands for creating tarfile to log file
        echo "tarring the $origcount DICOMS" &>> "$logfilepath"
        echo "cd / && tar -cf $tarfile $dir" &>> "$logfilepath"

        # Create tarfile
        cd / && tar -cf "$tarfile" "$dir"

        # Print commands for gzipping tarfile to log file
        echo "gzip $tarfile" &>> "$logfilepath"

        # Gzip tarfile
        gzip "$tarfile"

        # Count files in gzipped tarfile
        tarcount=$(tar ztf "$ziptar" | wc -l)

        # Print DICOM count in converted tar.zip.
        echo "$tarcount DICOMS processed" &>> "$logfilepath"

        # If tarcount matches origcount, print rm command to log file
        if [ "$tarcount" -eq "$origcount" ]; then
            # Print command to log file
            echo "number of DICOMS match original and tar.zip - DELETING $fulldir" &>> "$logfilepath"
            rm -rf "$fulldir"
        else
            # If tarfile is not good, print message to log file
            echo "counts of DICOMS don't match in tar.zip - NOT DELETING $fulldir" &>> "$logfilepath"
        fi
    else
        # If tarfile already exists, print message to log file
        echo "$tarfile exists already. Check & Remove $fulldir mannually" &>> "$logfilepath"
    fi
    
    # Add a separator between entries
    echo "--------------------------------------------------------" >> "$logfilepath"

done <<< "$OLD"

# Close log file
exec 3>&1 1>>"$logfilepath" 2>&1
