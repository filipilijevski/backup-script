#!/bin/bash

# function to timestamp log messages 
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$log_dir/$log_file"
}

# function to send emails using mutt
send_email() {
    local subject="$1"
    local body="$2"
    local recipient="filipzilijevski@gmail.com"

    if command -v mutt > /dev/null 2>$1; then
        echo "$body" | mutt -s "$subject" "$recipient"
    else
        log_message "Warning: mutt is not installed. Unable to send email notifications."
    fi
}

# check to see if the correct number of arguments is provided (2 args)
if [ $# -ne 2 ]; then
    echo "Usage: backupscript.sh <source_directory> <target_directory>"
    echo "Please try again."
    exit 1
fi

# set current date for log and backup directory names
current_date=$(date +"%Y-%m-%d")
log_dir="logs"
log_file="backup_${current_date}.log"

# create the log directory if it does not exist
mkdir -p "$log_dir"

# check if rsync is installed
if ! command -v rsync > /dev/null 2>&1; then
    log_message "ERROR: This script requires rsync to run properly. Please install rsync and try again."
    send_email "Backup Script Error" "ERROR: rsync is not installed. Please install rsync and try running the script again."
    exit 2
fi

# check if source directory exists and is readable
if [ ! -d "$1" ] || [ ! -r "$1" ]; then
    log_message "ERROR: The source directory '$1' does not exist or is not readable. Please check the path and permissions."
    send_email "Backup Script Error" "ERROR: The source directory '$1' is not readable or does not exist. Please check paths and permissions." 
    exit 3
fi

# check if target directory exists and is writable
if [ ! -d "$2" ] || [ ! -w "$2" ]; then
    log_message "ERROR: The target directory '$2' does not exist or is not writable. Please check the path and permissions."
    send_email "Backup Script Error" "ERROR: The target directory '$2' is not writable or does not exist. Please check paths and permissions."
    exit 4
fi

# rsync options for this specific script
rsync_options="-avb --backup-dir=$2/$current_date --delete --dry-run"

# start the backup process
log_message "----------------------------------------"
log_message "Backup started."
log_message "Source Directory: $1"
log_message "Target Directory: $2/current"
log_message "Backup Directory: $2/$current_date"
log_message "----------------------------------------"

# execute rsync and check for errors
if rsync $rsync_options "$1" "$2/current"; then
    log_message "Backup completed successfully."
    send_email "Backup Completed Succesfully" "The backup process has been completed successfully. Please check log file for more details: $log_dir/$log_file"
else
    log_message "ERROR: Backup failed during execution."
    send_email "Backup Script Error" "ERROR: The backup process failed during execution. Please check log file for more details: $log_dir/$log_file"
fi

log_message "----------------------------------------"

