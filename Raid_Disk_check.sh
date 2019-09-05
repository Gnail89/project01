#!/bin/bash

export umask=022
basepath=$(cd `dirname $0`;pwd)

megacli_tool="/opt/MegaRAID/MegaCli/MegaCli64"
ssacli_tool="/sbin/ssacli"

log_file="${basepath}/Raid_Disk_check.log"
result_file="${basepath}/raid_disk_result.txt"


function chk_file(){
    cat /dev/null > ${result_file}
    if [ $? -eq 0 ]; then
        chmod a+r ${result_file}
    else
        exit 0
    fi
}


function MegaCli_Raid_inspect(){
    # return code 0 : means it's normal status
    # return code 1 : means it's fault status
    if [ -x ${megacli_tool} ]; then
        if [ $(${megacli_tool} -AdpAllInfo -aAll | grep "Critical Disk" | awk {'print $4'}) -eq 0 -a $(${megacli_tool} -AdpAllInfo -aAll | grep "Failed Disk" | awk {'print $4'}) -eq 0 ]; then
            result_stat=0
        else
            result_stat=1
        fi
    else
        exit 0
    fi
}


function Ssacli_Raid_inspect(){
    # return code 0 : means it's normal status
    # return code 1 : means it's fault status
    if [ -x ${ssacli_tool} ]; then
        if [ $(${ssacli_tool} ctrl all show config |grep physicaldrive |grep -Ev "OK|$" |wc -l) -eq 0 ]; then
            result_stat=0
        else
            result_stat=1
        fi
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
                Ssacli_Raid_inspect
                ;;
            *)
                MegaCli_Raid_inspect
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
