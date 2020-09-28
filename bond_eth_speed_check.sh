#!/bin/bash

export PATH=/sbin:/bin:/usr/sbin:/usr/bin

result_info=""
bond_path="/proc/net/bonding"

function msg_box(){
    local holder_str=";"
    if [ x"${result_info}" == x"" ]; then
        result_info="$1"
    else
        result_info="${result_info}${holder_str}${1}"
    fi
}

function bond_eth_dect(){
    if [ -d ${bond_path} ]; then
        for bond_name in $(ls ${bond_path});do
            if [ -r "${bond_path}/${bond_name}" ]; then
                for eth_name in $(sed -n "/Slave Interface\:/s/.*Slave Interface: //p" "${bond_path}/${bond_name}");do
                    local eth_speed="$(ethtool ${eth_name} |sed -n "/Speed\:/s/.*Speed: //p" |egrep -o "[[:digit:]]+")"
                    local eth_max_speed="$(echo $(ethtool ${eth_name}) |egrep -o "Supported link modes:.*Full Supported" |awk '{print $(NF-1)}' |egrep -o "[[:digit:]]+")"
                    if [ x"${eth_max_speed}" != x"${eth_speed}" ]; then
                        [ x"${eth_speed}" == x"" ] && eth_speed="down"
                        msg_box "${bond_name},${eth_name},${eth_speed}"
                    fi
                done
            fi
        done
    fi
}

function main(){
    bond_eth_dect
}

main

if [ x"${result_info}" != x"" ]; then
    echo "${result_info}" > /tmp/bond_eth_speed_check.txt
    sleep 3600
    echo '0' > /tmp/bond_eth_speed_check.txt
else
    echo '0' > /tmp/bond_eth_speed_check.txt
fi
