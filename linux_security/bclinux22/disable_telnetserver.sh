#!/usr/bin/env bash

systemctl disable telnet.socket
systemctl is-active telnet.socket
if [ $? -eq 0 ]; then
    systemctl stop telnet.socket
fi
