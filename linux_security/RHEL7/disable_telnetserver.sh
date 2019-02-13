#!/usr/bin/env bash
. ./setenv.sh

systemctl disable telnet.socket
systemctl status telnet.socket
if [ $? -eq 0 ]; then
    systemctl stop telnet.socket
fi
