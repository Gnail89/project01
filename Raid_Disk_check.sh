#!/bin/bash

umask 022
basepath=$(cd `dirname $0`;pwd)

megacli_tool="/opt/MegaRAID/MegaCli/MegaCli64"
ssacli_tool="/sbin/ssacli"

log_file="${basepath}/Raid_Disk_check.log"
result_file="/home/user/raid_disk_result.txt"
result_file_vd="/home/user/raid_vdisk_result.txt"


chk_file(){
    cat /dev/null > ${result_file}
    if [ $? -eq 0 ]; then
        chmod a+r ${result_file}
    else
        exit 0
    fi
    
    cat /dev/null > ${result_file_vd}
    if [ $? -eq 0 ]; then
        chmod a+r ${result_file_vd}
    else
        exit 0
    fi
}


MegaCli_Raid_inspect(){
    # return code 0 : means it's normal status
    # return code 1 : means it's fault status
    if [ -f ${megacli_tool} ]; then
        if [ x$(sudo ${megacli_tool} -AdpAllInfo -aAll -NoLog |grep "Failed Disk" | awk {'print $4'}) == x0 ]; then
            result_stat=0
        else
            result_stat=1
        fi
        if [ ${result_stat} -ne 0 ]; then
            local flagtag=0
            for esid in $(sudo ${megacli_tool} -PDList -aALL -NoLog |egrep "(Enclosure Device ID|Slot Number)" |sed -e "N;s/\nSlot Number[[:space:]]*:[[:space:]]*\(.*\)/:\1/g" -e "s/Enclosure Device ID[[:space:]]*:[[:space:]]*//g"); do
                local pdstat="$(sudo ${megacli_tool} -pdInfo -PhysDrv[${esid}] -aALL -NoLog |egrep "\<Firmware state\>" |sed -e "s/Firmware state[[:space:]]*:[[:space:]]*//g")"
                local pdsize="$(sudo ${megacli_tool} -pdInfo -PhysDrv[${esid}] -aALL -NoLog |egrep "\<Raw Size\>" |sed -e "s/Raw Size[[:space:]]*:[[:space:]]*//g" -e "s/[[:space:]]*\[.*\]//g")"
                local pdtype="$(sudo ${megacli_tool} -pdInfo -PhysDrv[${esid}] -aALL -NoLog |egrep "\<PD Type\>" |sed "s/PD Type[[:space:]]*:[[:space:]]*//g")"
                if [ x"${pdstat}" == x"Failed" ] || [ x"${pdstat}" == x"Critical" ] || [ x"${pdstat}" == x"Unconfigured Bad" ] || [ x"${pdstat}" == x"failed" ] || [ x"${pdstat}" == x"critical" ] || [ x"${pdstat}" == x"unconfigured bad" ]; then
                    if [ ${flagtag} -ne 0 ]; then
                        result_info="${result_info}||id::${esid}|state::${pdstat}|size::${pdsize}|type::${pdtype}"
                    else
                        result_info="id::${esid}|state::${pdstat}|size::${pdsize}|type::${pdtype}"
                        flagtag=1
                    fi
                fi
            done
        fi
    else
        exit 0
    fi
}


MegaCli_Raid_vd_stat(){
    # return code 0 : means it's normal status
    # return other code : means it's fault status
    if [ -f ${megacli_tool} ]; then
        echo "$(sudo ${megacli_tool} -AdpAllInfo -aAll -NoLog |egrep "^[[:space:]]+\<Degraded\>" |sed "s/^[[:space:]]\+\<Degraded\>[[:space:]]\+:[[:space:]]\+//g")" > ${result_file_vd}
    fi
}


Ssacli_Raid_inspect(){
    # return code 0 : means it's normal status
    # return code 1 : means it's fault status
    if [ -f ${ssacli_tool} ]; then
        if [ $(sudo ${ssacli_tool} ctrl all show config |grep physicaldrive |grep -Ev "OK|$" |wc -l) -eq 0 ]; then
            result_stat=0
        else
            result_info="$(sudo ${ssacli_tool} ctrl all show config |grep physicaldrive |egrep -v "OK" |sed -e 's/[[:space:]]*physicaldrive[[:space:]]*//g' -e 's/$/\|/g' |tr '\n' '|' |sed 's/||$/\n/')"
            result_stat=1
        fi
    else
        exit 0
    fi
}


Ssacli_Raid_vd_stat(){
    if [ -f ${ssacli_tool} ]; then
        echo "$(sudo ${ssacli_tool} ctrl all show config |egrep "^[[:space:]]+logicaldrive" |egrep -v "OK" |wc -l)" > ${result_file_vd}
    fi
}


result_out(){
    if [ ${result_stat} -eq 1 ]; then
        echo "${result_info}" > ${result_file}
    else
        echo 0 > ${result_file}
    fi
}


help_info(){
    echo "
Usage:
    $0 <option>
Options:
    megaraid
                run LSI MegaRAID script for inspect
    ssaraid
                run HP SSA RAID script for inspect
    setup_megaraid
                setup megaraid environment
    setup_ssaraid
                setup ssaraid environment
    "
}


megaraid_setup(){
    [ x"$(whoami)" != x"root" ] && echo "the option need root privilege" && exit 0
    echo -n '1. setup sudo at /etc/sudoers.d/cloud'
    if [ -d /etc/sudoers.d ]; then
        [ -f /etc/sudoers.d/cloud ] && cp /etc/sudoers.d/cloud /tmp/cloud.bak.$(date "+%s")
        echo 'Defaults:cloud    !requiretty
cloud    ALL=(ALL)    NOPASSWD:/opt/MegaRAID/MegaCli/MegaCli64,/sbin/ssacli,/sbin/ethtool,/usr/sbin/arcconf,/sbin/multipathd show paths,/sbin/multipathd show maps' > /etc/sudoers.d/cloud
        echo "      complete"
    else
        echo "      failed"
    fi

    echo -n '2. setup script copy to /home/user/Raid_Disk_check.sh'
    if [ -f "${basepath}/$0" ]; then
        \cp "${basepath}/$0" /home/user/Raid_Disk_check.sh
        [ -f /home/user/Raid_Disk_check.sh ] && chown cloud: /home/user/Raid_Disk_check.sh
        echo "      complete"
    else
        echo "      failed"
    fi

    echo -n '3. setup crontab task for cloud'
    local tmp_cron="cron.$(date "+%s").tmp"
    crontab -l -u cloud > ${tmp_cron}
    sed -i "/Raid_Disk_check.sh/d" ${tmp_cron}
    echo '0 9,17 * * * /bin/sh /home/user/Raid_Disk_check.sh megaraid &>/dev/null' >> ${tmp_cron}
    crontab -u cloud ${tmp_cron}
    rm -f ${tmp_cron}
    echo "      complete"

    echo -n '4. install megaraid cli tool'
    rpm -ivh http://172.16.1.1:8080/Raid_Disk_check/MegaCli-8.07.14-1.noarch.rpm &> /dev/null
    [ $? -ne 0 ] && rpm -ivh http://172.16.2.1:8080/Raid_Disk_check/MegaCli-8.07.14-1.noarch.rpm &> /dev/null
    [ $? -ne 0 ] && echo '      failed. Please manual install megaraid cli tool: rpm -ivh MegaCli-8.07.14-1.noarch.rpm' && exit 0 || echo "      complete"
}


ssaraid_setup(){
    [ x"$(whoami)" != x"root" ] && echo "the option need root privilege" && exit 0
    echo -n '1. setup sudo at /etc/sudoers.d/cloud'
    if [ -d /etc/sudoers.d ]; then
        [ -f /etc/sudoers.d/cloud ] && cp /etc/sudoers.d/cloud /tmp/cloud.bak.$(date "+%s")
        echo 'Defaults:cloud    !requiretty
cloud    ALL=(ALL)    NOPASSWD:/opt/MegaRAID/MegaCli/MegaCli64,/sbin/ssacli,/sbin/ethtool,/usr/sbin/arcconf,/sbin/multipathd show paths,/sbin/multipathd show maps' > /etc/sudoers.d/cloud
        echo "      complete"
    else
        echo "      failed"
    fi

    echo -n '2. setup script copy to /home/user/Raid_Disk_check.sh'
    if [ -f "${basepath}/$0" ]; then
        \cp "${basepath}/$0" /home/user/Raid_Disk_check.sh
        [ -f /home/user/Raid_Disk_check.sh ] && chown cloud: /home/user/Raid_Disk_check.sh
        echo "      complete"
    else
        echo "      failed"
    fi

    echo -n '3. setup crontab task for cloud'
    local tmp_cron="cron.$(date "+%s").tmp"
    crontab -l -u cloud > ${tmp_cron}
    sed -i "/Raid_Disk_check.sh/d" ${tmp_cron}
    echo '0 9,17 * * * /bin/sh /home/user/Raid_Disk_check.sh ssaraid &>/dev/null' >> ${tmp_cron}
    crontab -u cloud ${tmp_cron}
    rm -f ${tmp_cron}
    echo "      complete"

    echo -n '4. install ssaraid cli tool'
    rpm -ivh http://172.16.1.1:8080/Raid_Disk_check/ssacli-3.30-14.0.x86_64.rpm &> /dev/null
    [ $? -ne 0 ] && rpm -ivh http://172.16.2.1:8080/Raid_Disk_check/ssacli-3.30-14.0.x86_64.rpm &> /dev/null
    [ $? -ne 0 ] && echo '      failed. Please manual install ssaraid cli tool: rpm -ivh ssacli-3.30-14.0.x86_64.rpm' && exit 0 || echo "      complete"
}


main(){
    local self="$1"
    result_stat=""
    result_info=""
    case ${self} in
        ssaraid)
            chk_file
            Ssacli_Raid_inspect
            Ssacli_Raid_vd_stat
            result_out
            ;;
        megaraid)
            chk_file
            MegaCli_Raid_inspect
            MegaCli_Raid_vd_stat
            result_out
            ;;
        setup_ssaraid)
            ssaraid_setup
            ;;
        setup_megaraid)
            megaraid_setup
            ;;
        *)
            help_info
            exit 0
            ;;
    esac
}


main "$@"

sleep 7200
echo 0 > ${result_file}
echo 0 > ${result_file_vd}
