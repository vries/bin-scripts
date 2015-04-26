#!/bin/bash

# based on:
# http://stackoverflow.com/questions/1058047/wait-for-any-process-to-finish/11719943#11719943

PID="$1"
if [ $# -eq 2 ]; then
    sleeptime="$2"
else
    sleeptime="1"
fi

while [[ ( -d /proc/$PID ) && ( -z `grep zombie /proc/$PID/status` ) ]]; do
    sleep "$sleeptime"
done
