#!/usr/bin/env bash
. ./setenv.sh

chkconfig telnet off
systemctl status xinetd
if [ $? -eq 0 ]; then
    systemctl restart xinetd
fi
