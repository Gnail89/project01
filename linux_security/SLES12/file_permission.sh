#!/usr/bin/env bash

p_400_list=('/etc/shadow')
p_600_list=('/var/log/messages' '/var/log/secure' '/var/log/mail' '/var/log/mail.err' '/var/log/mail.info' '/var/log/mail.warn' '/var/log/cron' '/var/log/spooler' '/var/log/boot.log')
p_644_list=('/etc/passwd' '/etc/group')

# permission 400
for p_400_item in "${p_400_list[@]}"; do
    if [ -f ${p_400_item} ]; then
        chmod 400 ${p_400_item}
    fi
done
# permission 600
for p_600_item in "${p_600_list[@]}"; do
    if [ -f ${p_600_item} ]; then
        chmod 600 ${p_600_item}
    fi
done
# permission 644
for p_644_item in "${p_644_list[@]}"; do
    if [ -f ${p_644_item} ]; then
        chmod 644 ${p_644_item}
    fi
done
