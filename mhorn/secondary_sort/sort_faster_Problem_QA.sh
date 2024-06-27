#!/bin/bash

# Script for processing DICOM files and organizing them based on certain criteria

# Set environment variables for dcmtk package
export PATH=$PATH:/home/mribkup/dcmtk/usr/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/mribkup/dcmtk/usr/lib64
export DCMDICTPATH=/home/mribkup/dcmtk/usr/share/dcmtk/dicom.dic

# Get the current date and time for log file
rundate=$(date +"%Y-%m-%d_%H-%M-%S")
logfile="runlog-v2-240328_QA-${rundate}.log"
logfilepath="/home/mribkup/xnat-mribkup/mhorn/secondary_sort/LOGS/${logfile}"

# Create log file
touch "$logfilepath"

# Loop through each DICOM file
find /cnc/DATA/tmp -type f -name "*240328_QA*.dcm" -print0 | sort -z | while IFS= read -r -d '' path; do
    echo "Starting ..."
    echo "$path"
    # Log the current file path
    echo "[$path]" >> "$logfilepath"

    # Extract filename from the path
    filename=$(basename "$path")

    # Extract Instance Date and Investigator from DICOM header
    header=$(dcmdump "$path")
    #DatefromHeader=$(echo "$header" | grep -E '0008,0012|0008,0020' | sed 's/.*\[\(.*\)\].*/\1/' | tail -n 1)
    #InvestigatorfromHeader=$(echo "$header" | grep '0008,1030' | sed 's/.*\[\(.*\)\].*/\1/' | tr -d '[:space:]')
    #Investigator=$(echo "$header" | grep '0008,1030' | sed 's/.*\[\(.*\)\].*/\1/' | awk '{print $NF}')
    # If there's no Date in the header, log and skip
    #if [ -z "$DatefromHeader" ]; then
    #    echo "DatefromHeader is empty for path: $path" >> "$logfilepath"
    #   echo "--------------------------------------------------------" >> "$logfilepath"
        #continue
    #fi
   # echo "$DatefromHeader" >> "$logfilepath"

    # If there's no Investigator from the header, log and skip
    #if [ -z "$InvestigatorfromHeader" ]; then
    #    echo "InvestigatorfromHeader is empty for path: $path" >> "$logfilepath"
    #    echo "--------------------------------------------------------" >> "$logfilepath"
        #continue
    #fi
    #echo "$InvestigatorfromHeader" >> "$logfilepath"

    # Define the new path based on Investigator and ID
    newpath_prefix="/cnc/DATA/INVESTIGATORS/INVESTIGATORS_"
   
    # Extract ID from the filename
    IDfromHeader=$(echo "$header" | grep '0010,0020' | sed 's/.*\[\(.*\)\].*/\1/' | tail -n 1)
    # If there's no ID from the header, log and skip 
    if [ -z "$IDfromHeader" ]; then
        echo "IDfromHeader is empty for path: $path" >> "$logfilepath"
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi
    echo "$IDfromHeader" >> "$logfilepath"

    newpath="${newpath_prefix}/"SHRUTHI"/${IDfromHeader}"
    echo "$newpath" >> "$logfilepath"

    # Check if the destination file exists
    if [[ -e "$newpath/$filename" ]]; then
        echo "File exists in destination, removing: $path" >> "$logfilepath"
        rm "$path"
    else
        # Move the file to the new path
        mkdir -p "$newpath"
        mv "$path" "$newpath/$filename"
        echo "Moved file to: $newpath/$filename" >> "$logfilepath"
    fi
    echo "Done."
done

# Log the completion of the process
echo "$(date)" >> "$logfilepath"
