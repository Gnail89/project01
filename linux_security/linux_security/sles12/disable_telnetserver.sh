#!/usr/bin/env bash

chkconfig telnet off
systemctl status xinetd
if [ $? -eq 0 ]; then
    systemctl restart xinetd
fi
