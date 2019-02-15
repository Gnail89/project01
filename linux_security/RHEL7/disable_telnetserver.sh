#!/usr/bin/env bash

systemctl disable telnet.socket
systemctl status telnet.socket
if [ $? -eq 0 ]; then
    systemctl stop telnet.socket
fi
