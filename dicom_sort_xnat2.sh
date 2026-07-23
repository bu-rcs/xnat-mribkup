#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# Script for processing DICOM files and organizing them based on certain criteria

# path to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for dry-run flag
DRYRUN=false
if [[ "$1" == "--dryrun" ]]; then
    DRYRUN=true
    echo "=== DRY RUN MODE - No actual file operations will be performed ==="
fi

# Set environment variables for dcmtk package
export PATH=$PATH:/home/mribkup/dcmtk/usr/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/mribkup/dcmtk/usr/lib64
export DCMDICTPATH=/home/mribkup/dcmtk/usr/share/dcmtk/dicom.dic

# Verify /cnc is actually mounted before doing any work. If the AD account
# backing this CIFS mount is disabled/expired, /cnc silently reverts to an
# empty local directory: every find/touch below then fails or returns
# nothing, and the "files remaining" email at the end falsely reports 0,
# as if everything had already been archived. Fail loudly instead.
if ! mountpoint -q /cnc || [[ ! -d /cnc/DATA || ! -d /cnc/LOGS ]]; then
    ALERTMSG="ERROR: /cnc is not mounted (or missing expected subdirectories) on $(hostname -f 2>/dev/null || hostname) as of $(date). dicom_sort_xnat2.sh aborted without processing any files. Check 'systemctl status cnc.mount' and the AD account status for the service account in /etc/credentials."
    echo "$ALERTMSG" >&2
    echo "$ALERTMSG" >> "$SCRIPT_DIR/mount_alerts.log"
    if $DRYRUN; then
        echo "[DRY RUN] Would send email to xnat-admin@scv.bu.edu with subject: ALERT: /cnc not mounted - dicom_sort_xnat2.sh aborted"
    else
        echo -e "Subject:ALERT: /cnc not mounted - dicom_sort_xnat2.sh aborted\n\n$ALERTMSG" | /sbin/sendmail -v "xnat-admin@scv.bu.edu"
    fi
    exit 1
fi

# Get list of directories containing DICOM files
# Find all .dcm files, get their parent directories, and get unique list
SERIES_DIRS=$(find /cnc/DATA/tmp -type f -name "*.dcm" -exec dirname {} \; | sort -u)

# Get the current date and time for log file
rundate=$(date +"%Y-%m-%d_%H-%M-%S")
if $DRYRUN; then
    logfile="runlog-DRYRUN-${rundate}.log"
else
    logfile="runlog-${rundate}.log"
fi
logfilepath="/cnc/LOGS/${logfile}"

# Create log file
touch "$logfilepath"

if $DRYRUN; then
    echo "=== DRY RUN MODE - No actual file operations will be performed ===" >> "$logfilepath"
    echo "" >> "$logfilepath"
fi

# Loop through each series directory
for series_dir in $SERIES_DIRS; do

    # Log the current series directory
    echo "[Processing series directory: $series_dir]" >> "$logfilepath"

    # Get the series directory name (e.g., T1_MEMPRAGE_1.2mm_p4_9_MR)
    series_dirname=$(basename "$series_dir")
    echo "Series name: $series_dirname" >> "$logfilepath"

    # Find one DICOM file in this directory to extract metadata
    sample_dcm=$(find "$series_dir" -type f -name "*.dcm" | head -n 1)
    
    if [ -z "$sample_dcm" ]; then
        echo "No DICOM files found in $series_dir" >> "$logfilepath"
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi

    # Get the parent path to check for INVESTIGATORS/EXTERNALUSERS
    parent_path=$(dirname "$series_dir")

    # Determine prefix based on directory path content
    if [[ $parent_path =~ "ExternalUsers" || $parent_path =~ "EXTERNALUSERS" ]]; then
        newpath_prefix="/cnc/DATA/INVESTIGATORS/EXTERNALUSERS_"
        echo "EXTERNALUSERS" >> "$logfilepath"
    elif [[ $parent_path =~ "INVESTIGATORS" ]]; then
        newpath_prefix="/cnc/DATA/INVESTIGATORS/INVESTIGATORS_"
        echo "INVESTIGATORS" >> "$logfilepath"
    else
        # Handle case when neither "EXTERNALUSERS" nor "INVESTIGATORS" is present
        echo "Neither EXTERNALUSERS nor INVESTIGATORS found in path: $parent_path" >&2 
        echo "Neither EXTERNALUSERS nor INVESTIGATORS found in path: $parent_path" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi

    # Extract Instance Date from DICOM header
    DatefromHeader=$(dcmdump +P "0008,0012" "$sample_dcm" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    if [ -z "$DatefromHeader" ]; then
        DatefromHeader=$(dcmdump +P "0008,0020" "$sample_dcm" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    fi
    # If there's no Date in the header, note it and move on.
    if [ -z "$DatefromHeader" ]; then
        echo "DatefromHeader is empty for series: $series_dir" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"        
        continue
    fi
    echo "Date: $DatefromHeader" >> "$logfilepath"

    # Extract Investigator from the DICOM header
    InvestigatorfromHeader=$(dcmdump +P "0008,1030" "$sample_dcm" | awk '{gsub(/[\[\]]/, "", $4); if (index($3, "^") > 0) {gsub(/^.*\^|\].*$/, "", $3); print toupper($3)} else {print toupper($4)}}' | tail -n 1)
    # If there's no Investigator from the header, note it and move on.
    if [ -z "$InvestigatorfromHeader" ]; then
        echo "InvestigatorfromHeader is empty for series: $series_dir" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi 
    echo "Investigator: $InvestigatorfromHeader" >> "$logfilepath"

    #######################################################################
        # THIS IS FOR TESTING.
        # COMMENT OUT TO RUN FULLY. 
        # Only look for LING.
#    if [[ $InvestigatorfromHeader != "LING" ]]; then
#        echo "Investigator is not Ling. Skipping series." >> "$logfilepath"
        # Add a separator between entries
#        echo "--------------------------------------------------------" >> "$logfilepath"
#        continue
#    fi
    #######################################################################

    # Extract ID from the DICOM header
    IDfromHeader=$(dcmdump +P "0010,0020" "$sample_dcm" | awk '{gsub(/[\[\]]/, "", $3); print $3}' | tail -n 1)
    # If there's no ID from the header, note it and move on. 
    if [ -z "$IDfromHeader" ]; then
        echo "IDfromHeader is empty for series: $series_dir" >> "$logfilepath"
        # Add a separator between entries
        echo "--------------------------------------------------------" >> "$logfilepath"
        continue
    fi
    echo "Subject ID: $IDfromHeader" >> "$logfilepath"

    # Define the new path based on Investigator and ID
    newpath=${newpath_prefix}${InvestigatorfromHeader}/${IDfromHeader}
    echo "Target path: $newpath" >> "$logfilepath"

    # Some subject IDs (e.g. generic scanner QA IDs like "MR166024" or "test")
    # are reused across genuinely unrelated sessions. If dicom_maketar_xnat2.sh
    # already archived-and-deleted a prior session under this exact ID (leaving
    # a .tar/.tar.gz with no accompanying live directory), redirect this
    # incoming session up front so it never gets dumped into a freshly created
    # $newpath sitting next to a stale, unrelated archive.
    # NOTE: if a THIRD generation of this same recycled ID reuses the exact
    # same DatefromHeader as an already-redirected second generation, this
    # single-level check won't catch it; that (compound, currently
    # unobserved) case will still surface visibly as a "Hash mismatch - NOT
    # DELETING" line in dicom_maketar_xnat2.sh's log, same as today, just
    # against the suffixed path instead of the base path.
    if [[ ! -d "$newpath" ]] && [[ -e "${newpath}.tar.gz" || -e "${newpath}.tar" ]]; then
        echo "Archive already exists for $newpath but no live directory - subject ID may be reused for a new session" >> "$logfilepath"
        newpath="${newpath}_DUPLICATE_SESSION_ID_${DatefromHeader}"
        echo "Redirecting to: $newpath" >> "$logfilepath"
    fi

    # Check if the subject folder exists
    if [[ -d "$newpath" ]]; then
        echo "Subject folder exists" >> "$logfilepath"

        # Check if this exact series directory already exists in the target
        if [[ -d "$newpath/$series_dirname" ]]; then
            echo "Series directory already exists at destination" >> "$logfilepath"
            
            # Check existing series for date conflicts
            existing_dcm=$(find "$newpath/$series_dirname" -type f -name "*.dcm" | head -n 1)
            if [ -n "$existing_dcm" ]; then
                ExistingInstanceDate=$(dcmdump +P "0008,0012" "$existing_dcm" | awk '{gsub(/[\[\]]/, "", $3); print $3}')
                if [ -z "$ExistingInstanceDate" ]; then
                    ExistingInstanceDate=$(dcmdump +P "0008,0020" "$existing_dcm" | awk '{gsub(/[\[\]]/, "", $3); print $3}')
                fi
                echo "Instance Date from Current Series = $DatefromHeader" >> "$logfilepath"
                echo "Instance Date from Existing Series = $ExistingInstanceDate" >> "$logfilepath"

                # Check if Instance Dates differ
                if [[ "$DatefromHeader" != "$ExistingInstanceDate" ]]; then
                    # Different date - this is a duplicate session, move to separate folder
                    newpath="${newpath}_DUPLICATE_SESSION_ID_${DatefromHeader}"
                    echo "Duplicate Session detected - creating separate folder" >> "$logfilepath"
                    echo "New target path: $newpath" >> "$logfilepath"
                    
                    if [[ -d "$newpath/$series_dirname" ]]; then
                        echo "Series already exists in duplicate folder - removing from tmp" >> "$logfilepath"
                        if $DRYRUN; then
                            echo "[DRY RUN] Would execute: rm -rf \"$series_dir\"" >> "$logfilepath"
                        else
                            rm -rf "$series_dir"
                        fi
                    else
                        echo "Creating duplicate folder and moving series" >> "$logfilepath"
                        if $DRYRUN; then
                            echo "[DRY RUN] Would execute: mkdir -p \"$newpath\"" >> "$logfilepath"
                            echo "[DRY RUN] Would execute: mv \"$series_dir\" \"$newpath/\"" >> "$logfilepath"
                        else
                            mkdir -p "$newpath"
                            mv "$series_dir" "$newpath/"
                        fi
                    fi
                else
                    # Same date - verify content before removing
                    echo "Series with same date found - verifying content" >> "$logfilepath"
                    
                    if diff -qr "$series_dir" "$newpath/$series_dirname" > /dev/null 2>&1; then
                        echo "Content verified identical - removing from tmp" >> "$logfilepath"
                        if $DRYRUN; then
                            echo "[DRY RUN] Would execute: rm -rf \"$series_dir\"" >> "$logfilepath"
                        else
                            rm -rf "$series_dir"
                        fi
                    else
                        echo "WARNING: Same date but different content!" >> "$logfilepath"
                        
                        newpath="${newpath}_DUPLICATE_CONTENT_MISMATCH_${DatefromHeader}"
                        echo "Moving to: $newpath" >> "$logfilepath"
                        
                        if $DRYRUN; then
                            echo "[DRY RUN] Would execute: mkdir -p \"$newpath\"" >> "$logfilepath"
                            echo "[DRY RUN] Would execute: mv \"$series_dir\" \"$newpath/\"" >> "$logfilepath"
                        else
                            mkdir -p "$newpath"
                            mv "$series_dir" "$newpath/"
                        fi
                    fi
                fi
            else
                echo "WARNING: Existing series directory has no DICOM files" >> "$logfilepath"
                echo "Moving anyway to replace empty directory" >> "$logfilepath"
                if $DRYRUN; then
                    echo "[DRY RUN] Would execute: rm -rf \"$newpath/$series_dirname\"" >> "$logfilepath"
                    echo "[DRY RUN] Would execute: mv \"$series_dir\" \"$newpath/\"" >> "$logfilepath"
                else
                    rm -rf "$newpath/$series_dirname"
                    mv "$series_dir" "$newpath/"
                fi
            fi
        else
            # Series doesn't exist yet, just move it
            echo "Series doesn't exist in subject folder - moving" >> "$logfilepath"
            if $DRYRUN; then
                echo "[DRY RUN] Would execute: mv \"$series_dir\" \"$newpath/\"" >> "$logfilepath"
            else
                mv "$series_dir" "$newpath/"
            fi
        fi
    else
        # Create the subject folder if it doesn't exist
        echo "Subject folder doesn't exist - creating and moving series" >> "$logfilepath"
        if $DRYRUN; then
            echo "[DRY RUN] Would execute: mkdir -p \"$newpath\"" >> "$logfilepath"
            echo "[DRY RUN] Would execute: mv \"$series_dir\" \"$newpath/\"" >> "$logfilepath"
        else
            mkdir -p "$newpath"
            mv "$series_dir" "$newpath/"
        fi
    fi

    # Add a separator between entries
    echo "--------------------------------------------------------" >> "$logfilepath"

done

# Log the completion of the process
echo "$(date)" >> "$logfilepath"

# send an email of the left behind sort count
# Directory to count files in
DIRECTORY="/cnc/DATA/tmp"
# Count the files (recursively to catch any nested .dcm files)
FILE_COUNT=$(find "$DIRECTORY" -type f -name "*.dcm" | wc -l)
# Also count remaining series directories
SERIES_COUNT=$(find "$DIRECTORY" -type f -name "*.dcm" -exec dirname {} \; | sort -u | wc -l)
# Email details
TO="xnat-admin@scv.bu.edu"
SUBJECT="File Count in $DIRECTORY"
if $DRYRUN; then
    SUBJECT="[DRY RUN] File Count in $DIRECTORY"
fi
BODY="The number of DICOM files remaining in $DIRECTORY is: $FILE_COUNT
The number of series directories remaining is: $SERIES_COUNT"

if $DRYRUN; then
    BODY="[DRY RUN MODE - No files were actually moved]

$BODY"
fi

# Send the email
if $DRYRUN; then
    echo "[DRY RUN] Would send email to $TO with subject: $SUBJECT" >> "$logfilepath"
    echo "[DRY RUN] Email body:" >> "$logfilepath"
    echo "$BODY" >> "$logfilepath"
else
    echo -e "Subject:$SUBJECT\n\n$BODY" | /sbin/sendmail -v "$TO"
fi

if $DRYRUN; then
    echo ""
    echo "=== DRY RUN COMPLETE - Check log file: $logfilepath ==="
fi

# remove any empty directories left behind in tmp
find /cnc/DATA/tmp -maxdepth 2 -depth -type d -empty -delete