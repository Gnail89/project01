#!/bin/bash

if [ -r /proc/net/dev ] && [ -d /sys/class/net ]; then
    data_buff="$(cat /proc/net/dev;sleep 1;cat /proc/net/dev)"
    port_list="$(egrep -o "^.*:" /proc/net/dev |sed "s/:$//g")"
else
    data_buff=""
    port_list=""
fi

if [ x"${port_list}" != x""  ] && [ x"${data_buff}" != x"" ]; then
    for i in ${port_list};do
        port_state="$(cat /sys/class/net/${i}/operstate )"
        in1="$(echo "${data_buff}" |awk '/'${i}':/{print $2}' |sed -n 1p)"
        in2="$(echo "${data_buff}" |awk '/'${i}':/{print $2}' |sed -n 2p)"
        out1="$(echo "${data_buff}" |awk '/'${i}':/{print $10}' |sed -n 1p)"
        out2="$(echo "${data_buff}" |awk '/'${i}':/{print $10}' |sed -n 2p)"
        in_byte="$(( ${in2} - ${in1} ))"
        out_byte="$(( ${out2} - ${out1} ))"
        if [ x"${port_state}" == x"up" ]; then
            port_speed="$(cat /sys/class/net/${i}/speed)"
            if [ ${port_speed} -gt 0 ]; then
                in_rate="$(echo ${port_speed} |awk '{printf("%f","'"${in_byte}"'"/1024/1024/"'"${port_speed}"'")}')"
                out_rate="$(echo ${port_speed} |awk '{printf("%f","'"${out_byte}"'"/1024/1024/"'"${port_speed}"'")}')"
            else
                port_speed="0"
                in_rate="0"
                out_rate="0"
            fi
        else
            port_speed="0"
            in_rate="0"
            out_rate="0"
        fi
        if [ x"${res_str}" == x"" ]; then
            res_str="{\"interface\":\"${i}\",\"state\":\"${port_state}\",\"speed\":\"${port_speed}\",\"receive_rate\":\"${in_rate}\",\"transfer_rate\":\"${out_rate}\"}"
        else
            res_str="${res_str},{\"interface\":\"${i}\",\"state\":\"${port_state}\",\"speed\":\"${port_speed}\",\"receive_rate\":\"${in_rate}\",\"transfer_rate\":\"${out_rate}\"}"
        fi
    done
else
    echo "[{\"error\":\"获取数据失败\"}]"
    exit 0
fi

echo "[$(echo ${res_str})]"
exit 0
