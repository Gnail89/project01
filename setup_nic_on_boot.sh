#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
rhel_net_dir="/etc/sysconfig/network-scripts"
cron_task="@reboot /bin/sh ${basepath}/${0##*/} dhcp &>/dev/null"

rhel_net(){
    if [ -d /sys/class/net ]; then
        for i in $(ls /sys/class/net |egrep "^en|^eth"); do
            echo "TYPE=Ethernet
BOOTPROTO=dhcp
NAME=${i}
DEVICE=${i}
ONBOOT=yes" > ${rhel_net_dir}/ifcfg-${i}
        done
    fi
}

clean_reboot(){
    if [ "$(crontab -l |egrep "${basepath}/${0##*/}" |wc -l)" -ne 0 ]; then
        if [ -f /var/spool/cron/root ]; then
            echo > /var/spool/cron/root
        fi
    fi
    sleep 3 && /sbin/init 6
}

help_info(){
    echo "
Usage:
    $0 setup        setup crontab task for the script.
    $0 dhcp         setup interface configuration file for DHCP on boot.
    "
}

main(){
    case $1 in
    setup)
        if [ "$(crontab -l |egrep "${cron_task}" |wc -l)" -eq 0 ]; then
            if [ -d /var/spool/cron ]; then
                echo "${cron_task}" >> /var/spool/cron/root
            fi
        fi
        ;;
    dhcp)
        if [ -d ${rhel_net_dir} ]; then
            rhel_net
            clean_reboot
        fi
        ;;
    *)
        help_info
        ;;
    esac
}

main "$@"
