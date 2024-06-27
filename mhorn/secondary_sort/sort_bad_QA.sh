#!/bin/bash

# Define source and destination directories
src_dir="/cnc/DATA/tmp"
dest_dir="/cnc/DATA/tmp_QA_fail"
logfile="/cnc/DATA/move_qa_files.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$logfile"
}

# Create the destination directory if it doesn't exist
if [[ ! -d "$dest_dir" ]]; then
    mkdir -p "$dest_dir"
    if [[ $? -eq 0 ]]; then
        log "Created directory $dest_dir"
    else
        log "Failed to create directory $dest_dir"
        exit 1
    fi
fi

# Move files with the keyword '240328_QA'
files_moved=0
for file in "$src_dir"/*240328_QA*; do
    if [[ -f "$file" ]]; then
        mv "$file" "$dest_dir"
        if [[ $? -eq 0 ]]; then
            log "Moved $file to $dest_dir"
            files_moved=$((files_moved + 1))
        else
            log "Failed to move $file"
        fi
    fi
done

if [[ $files_moved -eq 0 ]]; then
    log "No files with keyword '240328_QA' found in $src_dir"
else
    log "Total files moved: $files_moved"
fi

echo "Script execution completed. Check $logfile for details."
