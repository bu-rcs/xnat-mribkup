#!/bin/bash

# 04/2024 update for XA30 software upgrade
# converted Perl to Bash

# loading the dcmtk package
export PATH=$PATH:/home/mribkup/dcmtk/usr/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/mribkup/dcmtk/usr/lib64
export DCMDICTPATH=/home/mribkup/dcmtk/usr/share/dcmtk/dicom.dic

# Get list of IMA files in the /cnc/DATA/tmp directory
TMPFILES=$(find /cnc/DATA/tmp -type f -name "*.dcm")

# Get the current date and time
rundate=$(date +"%Y-%m-%d_%H-%M-%S")
logfile="runlog-${rundate}.log"  # Define the name of the log file
logfilepath="/cnc/scripts/test/logs/${logfile}"

# Open the log file for writing
touch "$logfilepath"

# Loop through each path in TMPFILES
for path in $TMPFILES; do
    # Log the current path
    echo "[$path]" >> "$logfilepath"

    # Extract filename from the path
    filename=$(basename "$path")

    # Assuming $path contains the string "EXTERNALUSERS" or "INVESTIGATORS"
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
        continue
    fi

    # Extract Instance Date using dicom2 from the current path
    DatefromHeader=$(dcmdump +P "0008,0012" "$path" | awk '{gsub(/[\[\]]/, "", $3); print $3}')
    echo $DatefromHeader >> "$logfilepath"

    # Extract Investigator from the filename
    InvestigatorfromHeader=$(dcmdump +P "0008,1030" "$path" | awk '{gsub(/[\[\]]/, "", $4); if (index($3, "^") > 0) {gsub(/^.*\^|\].*$/, "", $3); print toupper($3)} else {print toupper($4)}}')
    echo $InvestigatorfromHeader >> "$logfilepath"

    # Extract ID and Investigator from the filename
    IDfromHeader=$(dcmdump +P "0010,0020" "$path" | awk '{gsub(/[\[\]]/, "", $3); print $3}')
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
                    echo "$newpath/$filename exists - going to delete" >> "$logfilepath"
                    echo "rm $newpath/$filename" >> "$logfilepath"  # Print command for dry run
                else
                    echo "$newpath/$filename doesnt exist - moving" >> "$logfilepath"
                    echo "mv $path $newpath/$filename" >> "$logfilepath"  # Print command for dry run
                fi
            else
                echo "mkdir -p $newpath" >> "$logfilepath"
                echo "mv $path $newpath/$filename" >> "$logfilepath"  # Print command for dry run
            fi
        else
            # Dates are same
            if [[ -e "$newpath/$filename" ]]; then
                echo "Found $filename in $newpath" >> "$logfilepath"
                echo "Deleting this instead of moving." >> "$logfilepath"
                echo "rm $path" >> "$logfilepath"  # Print command for dry run
            else
                echo "File doesnt exist but directory does, so we move it" >> "$logfilepath"
                echo "mv $path $newpath/$filename" >> "$logfilepath"  # Print command for dry run
            fi
        fi
    else
        # Create the new path if it doesn't exist
        echo "mkdir -p $newpath" >> "$logfilepath"
        echo "mv $path $newpath/$filename" >> "$logfilepath"  # Print command for dry run
    fi

    # Add a separator between entries
    echo "--------------------------------------------------------" >> "$logfilepath"

done

# Log the completion of the process and indicate that maketar would be invoked
echo "$(date)" >> "$logfilepath"
echo "Invoking maketar now (this is a dry run, no actual changes will be made)" >> "$logfilepath"