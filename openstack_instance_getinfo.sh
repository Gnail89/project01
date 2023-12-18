#!/bin/bash

log_file="instance_info_$(date "+%Y%m%d")_$(date "+%s").txt"

echo "get all volume info"
volumes="$(openstack volume list --long -f csv -c ID -c Name -c Status -c Size -c Type)"

echo "get all instance info"
echo "$(openstack server list --long -f csv --status ACTIVE -c ID -c Name -c Networks -c Host)" |while read line; do
    vmid="$(echo $line |awk -F',' '{print $1}' |sed "s/\"//g")"
    vm_name="$(echo $line |awk -F',' '{print $2}' |sed "s/\"//g")"
    vm_net="$(echo $line |awk -F',' '{print $3}')"
    vm_host="$(echo $line |awk -F',' '{print $4}' |sed "s/\"//g")"

    echo "${vm_name} ${vmid} ${vm_host} ${vm_net}"

    for i in $(nova volume-attachments ${vmid} |grep ${vmid} |awk -F'|' '{print $(NF-1)}'); do
        if [ x"$i" != x"" ]; then
            t="$(echo "${volumes}" |grep ${i})"
            vol_id="$(echo $t |awk -F',' '{print $1}' |sed "s/\"//g")"
            vol_name="$(echo $t |awk -F',' '{print $2}' |sed "s/\"//g")"
            vol_stat="$(echo $t |awk -F',' '{print $3}' |sed "s/\"//g")"
            vol_size="$(echo $t |awk -F',' '{print $4}' |sed "s/\"//g")"
            vol_type="$(echo $t |awk -F',' '{print $5}' |sed "s/\"//g")"
            echo "${vm_name}|${vmid}|${vm_host}|${vol_name}|${vol_id}|${vol_stat}|${vol_size}|${vol_type}|${vm_net}" >> ${log_file}
        fi
    done
done
