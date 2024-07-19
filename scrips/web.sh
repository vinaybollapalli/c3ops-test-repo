#!/bin/bash

# Define variables
SERVICE="apache2"
LOG_FILE="/var/log/apache2_monitor.log"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

# Check if apache2 service is running
if systemctl is-active --quiet $SERVICE; then
    echo "$DATE - $SERVICE is running." >> $LOG_FILE
else
    echo "$DATE - $SERVICE is not running. Restarting..." >> $LOG_FILE
    systemctl start $SERVICE
    if [ $? -eq 0 ]; then
        echo "$DATE - Successfully restarted $SERVICE." >> $LOG_FILE
    else
        echo "$DATE - Failed to restart $SERVICE." >> $LOG_FILE
    fi
fi