#!/bin/bash

#######################################################################################
# improvedbackup
#
# Description:
#   A reliable backup script that uses rsync. This script includes features such as 
#   logging, directory validation and configurability.
#
# Usage:
#   ./improvedbackup.sh <source_directory <target_directory>
#
# Requirements:
#   - rsync
#   - ssmtp
#
# Author:
#   Filip Zvezdan Ilijevski
#
# Date:
#   2024-11-01
#######################################################################################

set -euo pipefail
IFS=$'\n\t'

RSYNC_CMD=$(command -v rsync)
MAIL_CMD=$(command -v mail)
MKDIR_CMD=$(command -v mkdir)
CHMOD_CMD=$(command -v chmod)
TEE_CMD=$(command -v tee)
DATE_CMD=$(command -v date)
ECHO_CMD=$(command -v echo)

for cmd in "$RSYNC_CMD" "$MAIL_CMD" "$MKDIR_CMD" "$CHMOD_CMD" "$TEE_CMD" "$DATE_CMD" "$ECHO_CMD"; do
    if [ ! -x "$cmd" ]; then
        echo "ERROR: Required command $(basename "$cmd") not found or not executable." >&2
        exit 1
    fi
done

# function to timestamp log messages 
log_message() {
    local message="$1"
    "$ECHO_CMD" "$("$DATE_CMD" +"%Y-%m-%d %H:%M:%S") - $message" | "$TEE_CMD" -a "$log_dir/$log_file"
}

# function to send emails using ssmtp
send_email() {
    local subject="$1"
    local body="$2"
    local recipient="${EMAIL_RECIPIENT:-filipzilijevski@gmail.com}"

    if [ -x "$MAIL_CMD" ]; then
        # use mail from mailutils to send email
        echo "$body" | "$MAIL_CMD" -s "$subject" "$recipient" || {
            # log error if mail fails to send email
            log_message "ERROR: Failed to send email via mail."
            exit 6        
        }

    else
        # if neither ssmtp or mail is installed, log warning and continue with backup
        log_message "WARNING: 'mail' (from mailutils) is not found, email notifications will not be sent."
        exit 7
    fi
}

validate_directories() {
    local source="$1"
    local target="$2"

    # ensure that source and target directories are not empty strings
    if [ -z "$source" ] || [ -z "$target" ]; then
        log_message "ERROR: Source and target directories cannot be empty"
        send_email "Backup Script Error" "ERROR: Source and target directories cannot be empty. Please provide valid directory paths."
        exit 1
    fi

    # check if source and target directories are the same
    if [ "$source" -ef "$target" ]; then
        log_message "ERROR: Source and target directories cannot be the same as this may cause data corruption."
        send_email "Backup Script Error" "ERROR: Source and target directories cannot be the same. Please choose different directories as the source and target."
        exit 2
    fi

    # check if source directory exists and is readable
    if [ ! -d "$source" ] || [ ! -r "$source" ]; then
        log_message "ERROR: The source directory '$source' does not exist or is not readable. Please check paths and permissions."
        send_email "Backup Script Error" "ERROR: The source directory '$source' does not exist or is not readable. Please check paths and permissions."
        exit 3
    fi
 
    # check if target directory exists and is writable
    if [ ! -d "$target" ] || [ ! -w "$target" ]; then
        log_message "ERROR: The target directory '$target' does not exist or is not writable. Please check paths and permissions." 
        send_email "Backup Script Error" "ERROR: The target directory '$target' does not exist or is not writable. Please check paths and permissions." 
        exit 4
    fi
}

# set current date for log and backup directory names
current_date=$("$DATE_CMD" +"%Y-%m-%d")
log_dir="${LOG_DIR:-logs}"
log_file="backup_${current_date}.log"

# create the log directory if it does not exist and allow only owner to read, write and execute
"$MKDIR_CMD" -p "$log_dir"
"$CHMOD_CMD" 700 "$log_dir"

# determine if script should do a dry run based on the DRY_RUN environment variable
dry_run="${DRY_RUN:-false}"

# check if the correct number of arguments was provided (2 args)
if [ $# -ne 2 ]; then
    "$ECHO_CMD" "Usage: improvedbackup.sh <source_directory> <target_directory>"
    "$ECHO_CMD" "Please try again with the correct number of arguments."
    exit 1
fi

# assign variable names to arguments
source_dir="$1"
target_dir="$2"

if [ ! -x "$RSYNC_CMD" ]; then 
    log_message "ERROR: This script needs rsync to run properly. Please install rsync and try again."
    send_email "Backup Script Error" "ERROR: rsync is not installed. Please install rsync and try running the script again."
    exit 5
fi

# validate source and target directories
validate_directories "$source_dir" "$target_dir"

# configure rsync based on dry_run flag
if [ "$dry_run" = true ]; then
    rsync_options="-avb --backup-dir=$target_dir/$current_date --delete --dry-run"
    dry_run_status="ENABLED"
else
    rsync_options="-avb --backup-dir=$target_dir/$current_date --delete"
    dry_run_status="DISABLED"
fi

# start the backup process
log_message "----------------------------------------"
log_message "Backup started."
log_message "Source Directory: $source_dir"
log_message "Target Directory: $target_dir/current"
log_message "Backup Directory: $target_dir/$current_date"
log_message "Dry Run Mode: $dry_run_status"
log_message "----------------------------------------"

# execute rsync and check for errors
if "$RSYNC_CMD" $rsync_options "$source_dir" "$target_dir/current"; then
    log_message "Backup completed successfully."
    send_email "Backup Completed Succesfully" "The backup process has been completed successfully. Please check log file for more details: $log_dir/$log_file"
else
    log_message "ERROR: Backup failed during execution."
    send_email "Backup Script Error" "ERROR: The backup process failed during execution. Please check log file for more details: $log_dir/$log_file"
    exit 8
fi

log_message "----------------------------------------"

