#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
data_save_path="${basepath}/data"
log_dir="${data_save_path}/swift_tenants_status_`date '+%Y%m%d'`.log"
config_path="${basepath}/swift_tenants_status.conf"
secret_key=$1
var_retval=''

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start scripts." >> ${log_dir}
if [ ! -f ${config_path} ];then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${config_path} file not found." >> ${log_dir}
    exit 1
fi

while read line
    do
        if [ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]; then
             line=$(echo ${line} |openssl aes-256-cbc -d -k ${secret_key} -base64)
             tenant_name=`echo $line |awk -F '|' '{print $1}'`
             user_name=`echo $line |awk -F '|' '{print $2}'`
             user_pwd=`echo $line |awk -F '|' '{print $3}'`
            if [ ! -z ${tenant_name} ] && [ ! -z ${user_name} ] && [ ! -z ${user_pwd} ]; then
                echo "Tenant ${tenant_name} stat:" >> ${log_dir}
                /usr/bin/swift -V 2 -A http://127.0.0.1:35357/v2.0 -U ${tenant_name}:${user_name} -K ${user_pwd} stat --lh |awk 'NR>1 && NR<5' >> ${log_dir}
                var_retval=$?
                [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: retval status is ${var_retval} , pull tenant ${tenant_name} failed." >> ${log_dir}
            else
                echo "Tenant ${tenant_name} stat:" >> ${log_dir}
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: pull tenant ${tenant_name} failed." >> ${log_dir}
            fi
        fi
    done < ${config_path}

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended scripts." >> ${log_dir}
