#!/bin/bash
#
# Script to stop WiFi access point
# The script disables & stops the services

SERVICE_LIST="draws-manager"

# ===== function stop_service

function stop_service() {
    service="$1"
    systemctl is-enabled "$service" > /dev/null 2>&1
    if [ $? -eq 0 ] ; then
        echo "DISABLING $service"
        systemctl disable "$service"
        if [ "$?" -ne 0 ] ; then
            echo "Problem DISABLING $service"
        fi
    else
        echo "Service: $service already disabled."
    fi
    systemctl stop "$service"
    if [ "$?" -ne 0 ] ; then
        echo "Problem stopping $service"
    fi
}

# ===== main

# Be sure we're running as root
if [[ $EUID != 0 ]] ; then
   echo "Must be root"
   exit 1
fi

for service in `echo ${SERVICE_LIST}` ; do
#    echo "DEBUG: Stopping service: $service"
    stop_service $service
done
