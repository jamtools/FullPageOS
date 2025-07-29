#!/bin/bash

LOGFILE="/boot/boot_log.txt"
DATE=$(date -Iseconds)
echo "Boot at $DATE" >> "$LOGFILE"
