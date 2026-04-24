#!/bin/bash

# Set enviormental variables for dcmtk package
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
export PATH=$PATH:/home/mribkup/dcmtk/usr/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/mribkup/dcmtk/usr/lib64
export DCMDICTPATH=/home/mribkup/dcmtk/usr/share/dcmtk/dicom.dic

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
    origcount=$(find "$dir" -type f | wc -l)

    # Print DICOM count for study.
    echo "$origcount DICOMS to be processed" &>> "$logfilepath"

    # Define tar and gzipped tar file paths
    tarfile="${dir}.tar"
    ziptar="${tarfile}.gz"

    # Insert this checkpoint to make sure the correct level is being compressed
    # Checkpoint: Wait for user input to continue
    # read -rp "Press Enter to continue..."

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
        tarcount=$(tar -ztf "$ziptar" | grep -v '/$' | wc -l)

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
        # If tarfile already exists, check to see if it is an exact match to dir
        # If it is an exact match, then remove the original directory.
        echo "$tarfile exists already. Checking if archive and original directory match..." &>> "$logfilepath"
        if ./check_archive_files.sh "$ziptar" "$dir" "*.dcm"; then
            echo "Hashes match - DELETING $dir" &>> "$logfilepath"
            rm -rf "$dir"
        else
            echo "Hash mismatch - NOT DELETING $dir" &>> "$logfilepath"
            echo "$tarfile exists already. Check & Remove $fulldir manually" &>> "$logfilepath"
        fi
    fi

    # Add a separator between entries
    echo "--------------------------------------------------------" >> "$logfilepath"

done <<< "$OLD"

# Close log file
exec 3>&1 1>>"$logfilepath" 2>&1
