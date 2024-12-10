#!/bin/bash

host_list="$(egrep -v "^#|^$" /etc/hosts |grep cpt |awk '{print $2}')"
cpu_max="lscpu |grep \"^CPU(s):\" |awk '{print \$NF}'"
mem_max="grep ^MemTotal /proc/meminfo |awk '{printf \"%.2f\n\",\$(NF-1)/1024/1024}'"
mem_free="grep ^MemFree /proc/meminfo |awk '{printf \"%.2f\n\",\$(NF-1)/1024/1024}'"

printf "%-40s, %-12s, %-12s, %-12s, %-12s, %-12s, %-12s, %-12s \n" \
    "Hostname" \
    "CPU_Total" \
    "vCPU_Total" \
    "CPU_rate" \
    "MEM_Total" \
    "vMEM_Total" \
    "MEM_rate" \
    "MEM_Free"
    
flavor_list="$(openstack flavor list  -f value -c ID -c RAM -c VCPUs)"
    
for i in ${host_list}; do
    host_cpu_sum="$(ssh -oStrictHostKeyChecking=no ${i} "${cpu_max}" 2>/dev/null)"
    host_mem_sum="$(ssh -oStrictHostKeyChecking=no ${i} "${mem_max}" 2>/dev/null)"
    host_mem_free="$(ssh -oStrictHostKeyChecking=no ${i} "${mem_free}" 2>/dev/null)"
    vcpu_sum=0
    vmem_sum=0
    for vm_id in $(openstack server list -f value -c ID --status ACTIVE --host ${i});do
        flavor_id="$(openstack server show ${vm_id} -f value -c flavor |awk '{print $NF}' |sed -e 's/(//g' -e 's/)//g' |sed -n '1p')"
        tmp_mem="$(echo "${flavor_list}" |grep "^${flavor_id} " |awk '{printf "%.2f\n",$2/1024}')"
        tmp_cpu="$(echo "${flavor_list}" |grep "^${flavor_id} " |awk '{printf "%.2f\n",$3}')"
        if [ x"${tmp_mem}" != x"" ]; then
            vmem_sum=$(awk "BEGIN {print $vmem_sum+$tmp_mem}")
        fi
        if [ x"${tmp_cpu}" != x"" ]; then
            vcpu_sum=$(awk "BEGIN {print $vcpu_sum+$tmp_cpu}")
        fi
    done
    host_cpu_rate="$(echo "${vcpu_sum:-0} ${host_cpu_sum:-1}" |awk '{printf "%.2f\n",$1/$2*100}')"
    host_mem_rate="$(echo "${vmem_sum:-0} ${host_mem_sum:-1}" |awk '{printf "%.2f\n",$1/$2*100}')"
    printf "%-40s, %-12s, %-12s, %-12s, %-12s, %-12s, %-12s, %-12s \n" \
        "${i}" \
        "${host_cpu_sum:--1}" \
        "${vcpu_sum:--1}" \
        "${host_cpu_rate:-0} %" \
        "${host_mem_sum:-0} GB" \
        "${vmem_sum:-0} GB" \
        "${host_mem_rate:-0} %" \
        "${host_mem_free:-0} GB"
done
