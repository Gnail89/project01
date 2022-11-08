#!/bin/bash

time_delay="1"

declare -A data_buff1
declare -A data_buff2

if [ -d /sys/class/block ]; then
    dev_list="$(ls /sys/class/block/ |egrep -v "^dm-|^loop|^ram" |sed "s/[0-9]//g" |sort |uniq)"
else
    dev_list=""
fi

if [ x"${dev_list}" != x"" ]; then
    for i in ${dev_list}; do
        if [ -r "/sys/class/block/${i}/stat" ]; then
            data_buff1[${i}]="$(cat /sys/class/block/${i}/stat)"
        else
            data_buff1[${i}]="0"
        fi
    done
    sleep ${time_delay}
    for i in ${dev_list}; do
        if [ -r "/sys/class/block/${i}/stat" ]; then
            data_buff2[${i}]="$(cat /sys/class/block/${i}/stat)"
        else
            data_buff2[${i}]="0"
        fi
    done
    for i in ${dev_list}; do
        read_ms1="$(echo "${data_buff1[${i}]}" |awk '{print $4}')"
        read_ms2="$(echo "${data_buff2[${i}]}" |awk '{print $4}')"
        write_ms1="$(echo "${data_buff1[${i}]}" |awk '{print $8}')"
        write_ms2="$(echo "${data_buff2[${i}]}" |awk '{print $8}')"
        io_ms1="$(echo "${data_buff1[${i}]}" |awk '{print $10}')"
        io_ms2="$(echo "${data_buff2[${i}]}" |awk '{print $10}')"
        read_ms="$(echo |awk '{printf("%f",("'"${read_ms2}"'"-"'"${read_ms1}"'")/"'"${time_delay}"'")}')"
        write_ms="$(echo |awk '{printf("%f",("'"${write_ms2}"'"-"'"${write_ms1}"'")/"'"${time_delay}"'")}')"
        io_ms="$(echo |awk '{printf("%f",("'"${io_ms2}"'"-"'"${io_ms1}"'")/"'"${time_delay}"'")}')"
        if [ x"${res_str}" == x"" ]; then
            res_str="{\"dev_name\":\"${i}\",\"read_avg_ms\":\"${read_ms}\",\"write_avg_ms\":\"${write_ms}\",\"io_avg_ms\":\"${io_ms}\"}"
        else
            res_str="${res_str},{\"dev_name\":\"${i}\",\"read_avg_ms\":\"${read_ms}\",\"write_avg_ms\":\"${write_ms}\",\"io_avg_ms\":\"${io_ms}\"}"
        fi
    done
else
    echo "[{\"error\":\"获取磁盘设备列表失败\"}]"
    exit 0
fi

echo "[$(echo ${res_str})]"
exit 0
