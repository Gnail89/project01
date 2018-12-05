#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
log_dir="${basepath}/IPMI_password_change.log"
output_file="${basepath}/IPMI_password_change.conf"
input_file="${basepath}/IPMI-IP-list.conf"
var_retval=''

PingCheck(){
    ping -c 2 $host_ip &> /dev/null
    var_retval=$?
    if [ "$var_retval" -ne "0" ]; then
        ping -c 2 $host_ip &> /dev/null
        var_retval=$?
    fi
}

PingFailedMsg(){
    echo -e "\n\n###### $host_ip ping failed, please check. ######"
}

while read line
    do
        if [ ! -z `echo "$line" |sed '/^#/d' |sed '/^$/d'` ]; then
            host_ip=`echo $line |awk -F '|' '{print $1}' |awk '{print $1}'`
            port_num=`echo $line |awk -F '|' '{print $2}'`
            user_name=`echo $line |awk -F '|' '{print $3}'`
            user_pass=`echo $line |awk -F '|' '{print $4}'`
            user_new_pass="ACBD$(expr 100 + $(echo ${host_ip} |awk -F '.' '{print $3}'))*$(expr 11 + $(echo ${host_ip} |awk -F '.' '{print $4}'))"
            PingCheck
            if [ "$var_retval" -eq "0" ]; then
                user_id=$(ipmitool -I lanplus -H ${host_ip} -p ${port_num} -U ${user_name} -P ${user_pass} user list |grep ${user_name} |awk '{print $1}' )
                if [ ! -z ${user_id} ]; then
                    ipmitool -I lanplus -H ${host_ip} -p ${port_num} -U ${user_name} -P ${user_pass} user set password ${user_id} ${user_new_pass}
                    var_retval=$?
                    if [ "$var_retval" -eq "0" ]; then
                        echo "${host_ip}|${port_num}|${user_name}|${user_new_pass}|" >> ${output_file}
                    else
                        echo "${host_ip}|${port_num}|${user_name}|${user_new_pass}|it maybe wrong" >> ${output_file}
                    fi
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: user id is ${user_id} , value error ." >> ${log_dir}
                fi
                else
                PingFailedMsg 2>&1 >> ${output_file}
            fi
        fi
    done < ${input_file}
