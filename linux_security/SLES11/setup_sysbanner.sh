#!/usr/bin/env bash
. ./setenv.sh

f_sysbanner='Authorized users only. All activity may be monitored and reported'

echo "${f_sysbanner}" > /etc/motd

if [ -f /etc/issue ]; then
    mv /etc/issue{,.bak}
fi

if [ -f /etc/issue.net ]; then
    mv /etc/issue.net{,.bak}
fi
