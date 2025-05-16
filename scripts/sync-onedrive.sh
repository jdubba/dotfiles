#!/bin/bash

LOG_FILE='~/.var/sync-onedrive.log'

date >> $LOG_FILE
echo "--------------------------------------------------------" >> $LOG_FILE

# TODO: Read from rclone/local config file, and sync all folders
#Sync Documents
printf 'Syncing Poth directory\n\n' >> $LOG_FILE
rclone -v --log-file $LOG_FILE bisync rc-name:Path/ /local/path

printf '\n\n----------------------------------------------------\n\n\n' >> $LOG_FILE


