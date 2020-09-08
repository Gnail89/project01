#!/bin/bash

export umask=022
basepath=$(cd `dirname $0`;pwd)

megacli_tool="/opt/MegaRAID/MegaCli/MegaCli64"
ssacli_tool="/sbin/ssacli"

result_file="${basepath}/raid_disk_statistic.txt"


function chk_file(){
    cat /dev/null > ${result_file}
    if [ $? -eq 0 ]; then
        chmod a+r ${result_file}
    else
        exit 0
    fi
}


function MegaCli_Raid_disk(){
    if [ -x ${megacli_tool} ]; then
        result_stat="$(${megacli_tool} -AdpAllInfo -aAll -nolog | grep "Disks" | head -n 1 | awk {'print $3'})"
    else
        exit 0
    fi
}


function Ssacli_Raid_disk(){
    if [ -x ${ssacli_tool} ]; then
        result_stat="$(${ssacli_tool} ctrl all show config |grep physicaldrive |wc -l)"
    else
        exit 0
    fi
}


function main(){
    chk_file
    result_stat=""
    manufacturer=$(cat /sys/class/dmi/id/board_vendor |awk '{print $1}')
    if [ -n ${manufacturer} ]; then
        case ${manufacturer} in
            HP|hp)
                Ssacli_Raid_disk
                ;;
            *)
                MegaCli_Raid_disk
                ;;
        esac
    fi
    if [ -n ${result_stat} ]; then
        echo ${result_stat} > ${result_file}
    else
        cat /dev/null > ${result_file}
    fi
}


main
