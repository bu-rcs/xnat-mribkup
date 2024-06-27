#!/bin/bash

# Script for processing DICOM files and organizing them based on certain criteria

# Set environment variables for dcmtk package
export PATH=$PATH:/home/mribkup/dcmtk/usr/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/mribkup/dcmtk/usr/lib64
export DCMDICTPATH=/home/mribkup/dcmtk/usr/share/dcmtk/dicom.dic

# Get list of DICOM files in the specified directory
TMPFILES=$(find /cnc/DATA/tmp -type f -name "*BUMA317*.dcm")

# Get the current date and time for log file
rundate=$(date +"%Y-%m-%d_%H-%M-%S")
logfile="runlog-BUMA317-reverse-${rundate}.log"
logfilepath="/home/mribkup/xnat-mribkup/mhorn/secondary_sort/LOGS/${logfile}"

# Create log file
touch "$logfilepath"

# Loop through each DICOM file
for path in $TMPFILES; do
    # Log the current file path
    echo "[$path]" >> "$logfilepath"

    # Extract filename from the path
    filename=$(basename "$path")

    # Determine prefix based on filename content
    if [[ $filename =~ "ExternalUsers" ]]; then
        newpath_prefix="/cnc/DATA/INVESTIGATORS/EXTERNALUSERS_"
        echo "EXTERNALUSERS" >> "$logfilepath"
    elif [[ $filename =~ "INVESTIGATORS" ]]; then
        newpath_prefix="/cnc/DATA/INVESTIGATORS/INVESTIGATORS_"
        echo "INVESTIGATORS" >> "$logfilepath"
    else
        # Handle case when neither "EXTERNALUSERS" nor "INVESTIGATORS" is present
        echo "Neither EXTERNALUSERS nor INVESTIGATORS found in path" >&2 
        echo "Neither EXTERNALUSERS nor INVESTIGATORS found in path" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi

    # Extract Instance Date from DICOM header
    DatefromHeader=$(dcmdump +P "0008,0012" "$path" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    if [ -z "$DatefromHeader" ]; then
        DatefromHeader=$(dcmdump +P "0008,0020" "$path" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    fi
    # If there's no Date in the header, note it and move on.
    if [ -z "$DatefromHeader" ]; then
        echo "DatefromHeader is empty for path: $path" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"        
        continue
    fi
    echo $DatefromHeader >> "$logfilepath"

    # Extract Investigator from the filename
    InvestigatorfromHeader=$(dcmdump +P "0008,1030" "$path" | awk '{gsub(/[\[\]]/, "", $4); if (index($3, "^") > 0) {gsub(/^.*\^|\].*$/, "", $3); print toupper($3)} else {print toupper($4)}}' | tail -n 1)
    # If there's no Investigator from the header, note it and move on.
    if [ -z "$InvestigatorfromHeader" ]; then
        echo "InvestigatorfromHeader is empty for path: $path" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi 
    echo $InvestigatorfromHeader >> "$logfilepath"

    #######################################################################
        # THIS IS FOR TESTING.
        # COMMENT OUT TO RUN FULLY. 
        # Only look for LING.
#    if [[ $InvestigatorfromHeader != "STERN" ]]; then
#        echo "Investigator is not STERN. Skipping file." >> "$logfilepath"
        # Add a separator between entries
#        echo "--------------------------------------------------------" >> "$logfilepath"
#        continue
#    fi
    #######################################################################

    # Extract ID from the filename
    IDfromHeader=$(dcmdump +P "0010,0020" "$path" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    # If there's no ID from the header, note it and move on. 
    if [ -z "$IDfromHeader" ]; then
        echo "IDfromHeader is empty for path: $path" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi
    echo $IDfromHeader >> "$logfilepath"

    # Define the new path based on Investigator and ID
    newpath=${newpath_prefix}${InvestigatorfromHeader}/${IDfromHeader}
    echo $newpath >> "$logfilepath"

    # Check if the folder exists
    if [[ -d "$newpath" ]]; then
        echo "Folder exists" >> "$logfilepath"

        # Check existing study for conflicts 
        x=$(find "$newpath" -maxdepth 1 -name "*.dcm" | head -n 1)
        ExistingInstanceDate=$(dcmdump +P "0008,0012" "$x" | awk '{gsub(/[\[\]]/, "", $3); print $3}')
        echo "Instance Date from Current File = $DatefromHeader" >> "$logfilepath"
        echo "Instance Date from File in Directory = $ExistingInstanceDate" >> "$logfilepath"

        # Check if Instance Dates differ, if so create a duplicate folder
        if [[ "$DatefromHeader" != "$ExistingInstanceDate" ]]; then
            newpath="${newpath}_DUPLICATE_SESSION_ID_${DatefromHeader}"
            echo "Duplicate Session to be created" >> "$logfilepath"
            if [[ -d "$newpath" ]]; then
                echo "DUPLICATE Folder exists" >> "$logfilepath"
                if [[ -e "$newpath/$filename" ]]; then
                    echo "$newpath/$filename exists - going to delete from tmp" >> "$logfilepath"
                    rm $newpath/$filename  # Uncomment for actual execution
                else
                    echo "$newpath/$filename doesnt exist - moving from tmp" >> "$logfilepath"
                    mv $path $newpath/$filename  # Uncomment for actual execution
                fi
            else
                echo "$newpath doesn't exist - creating and moving from tmp" >> "$logfilepath"
                mkdir -p $newpath
                mv $path $newpath/$filename  # Uncomment for actual execution
            fi
        else
            # Dates are same
            if [[ -e "$newpath/$filename" ]]; then
                echo "Found $filename in $newpath" >> "$logfilepath"
                echo "Deleting this instead of moving." >> "$logfilepath"
                rm $path  # Uncomment for actual execution
            else
                echo "File doesnt exist but directory does, so we move it" >> "$logfilepath"
                mv $path $newpath/$filename  # Uncomment for actual execution
            fi
        fi
    else
        # Create the new path if it doesn't exist
        echo "$newpath doesn't exist - creating and moving from tmp" >> "$logfilepath"
        mkdir -p $newpath
        mv $path $newpath/$filename  # Uncomment for actual execution
    fi

    # Add a separator between entries
    echo "--------------------------------------------------------" >> "$logfilepath"

done

# Log the completion of the process
echo "$(date)" >> "$logfilepath"
