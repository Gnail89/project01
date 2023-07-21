#!/bin/bash

umask 022
basepath=$(cd `dirname $0`;pwd)
export PATH=/sbin:/bin:/usr/sbin:/usr/bin

result_info=""
bond_path="/proc/net/bonding"

msg_box(){
    local holder_str=";"
    if [ x"${result_info}" == x"" ]; then
        result_info="$1"
    else
        result_info="${result_info}${holder_str}${1}"
    fi
}

bond_eth_dect(){
    if [ -d ${bond_path} ]; then
        for bond_name in $(ls ${bond_path});do
            if [ -r "${bond_path}/${bond_name}" ]; then
                for eth_name in $(sed -n "/Slave Interface\:/s/.*Slave Interface: //p" "${bond_path}/${bond_name}");do
                    local eth_speed="$(ethtool ${eth_name} |sed -n "/Speed\:/s/.*Speed: //p" |egrep -o "[[:digit:]]+")"
                    local eth_max_speed="$(echo $(ethtool ${eth_name}) |egrep -o "Supported link modes:.*Full Support" |awk '{print $(NF-1)}' |egrep -o "[[:digit:]]+")"
                    if [ x"${eth_max_speed}" != x"${eth_speed}" ]; then
                        [ x"${eth_speed}" == x"" ] && eth_speed="down"
                        msg_box "${bond_name},${eth_name},${eth_speed}"
                    fi
                done
            fi
        done
    fi
}

help_info(){
    echo "
Usage:
    $0 <option>
Options:
    bond
                run interface bonding script for inspect
    setup_bond
                setup bonding check environment
    "
}

bond_setup(){
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

    echo -n '2. setup script copy to /home/user/bond_eth_speed_check.sh'
    if [ -f "${basepath}/$0" ]; then
        \cp "${basepath}/$0" /home/user/bond_eth_speed_check.sh
        [ -f /home/user/bond_eth_speed_check.sh ] && chown cloud: /home/user/bond_eth_speed_check.sh
        echo "      complete"
    else
        echo "      failed"
    fi
    
    echo -n '3. setup crontab task for cloud'
    local tmp_cron="cron.$(date "+%s").tmp"
    crontab -l -u cloud > ${tmp_cron}
    sed -i "/bond_eth_speed_check.sh/d" ${tmp_cron}
    echo '0 6,13 * * * /bin/sh /home/user/bond_eth_speed_check.sh bond &>/dev/null' >> ${tmp_cron}
    crontab -u cloud ${tmp_cron}
    rm -f ${tmp_cron}
    echo "      complete"
}

main(){
    local self="$1"
    case ${self} in
        bond)
            bond_eth_dect
            if [ x"${result_info}" != x"" ]; then
                echo "${result_info}" > /tmp/bond_eth_speed_check.txt
            else
                echo '0' > /tmp/bond_eth_speed_check.txt
            fi
            ;;
        setup_bond)
            bond_setup
            ;;
        *)
            help_info
            exit 0
            ;;
    esac
}

main "$@"
