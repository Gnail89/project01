#!/usr/bin/env bash

chkconfig telnet off
service xinetd status
if [ $? -eq 0 ]; then
    service xinetd restart
fi
