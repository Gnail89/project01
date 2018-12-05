#!/bin/bash
# config file format:
# tenant_name|user_name|user_passwd|save_root_path|container_name|object_name

basepath=$(cd `dirname $0`;pwd)
backup_config_path="${basepath}/swift_backup_list_$(date +'%Y-%m-%d').conf"
log_dir="${basepath}/swift_scripts.log"
var_retval=''

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start Swift backup scripts." >> ${log_dir}
echo "${backup_config_path}" >> ${log_dir}

if [ ! -f ${backup_config_path} ];then
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${backup_config_path} file not found." >> ${log_dir}
     exit 1
fi

if [ ! -f /usr/bin/swift ];then
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: /usr/bin/swift command not found." >> ${log_dir}
     exit 1
fi

while read line
    do
     if [ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]; then
         tenant_name=`echo $line |awk -F '|' '{print $1}'`
         user_name=`echo $line |awk -F '|' '{print $2}'`
         user_passwd=`echo $line |awk -F '|' '{print $3}'`
         save_root_path=`echo $line |awk -F '|' '{print $4}'`
         container_name=`echo $line |awk -F '|' '{print $5}'`
         object_name=`echo $line |awk -F '|' '{print $6}'`
         backup_dir="${save_root_path}/${container_name}"
         if [ ! -d ${backup_dir} ]; then
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ${backup_dir} not found , create it." >> ${log_dir}
             mkdir -p ${backup_dir}
            else
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: backup dir is ${backup_dir} , created." >> ${log_dir}
         fi
         if [ ! -z ${container_name} ] && [ ! -z ${object_name} ]; then
             cd ${backup_dir}
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: backup directory is ${backup_dir} , container is ${container_name} , object is ${object_name} , download file session starting." >> ${log_dir}
             /usr/bin/swift -V 2 -A http://127.0.0.1:5000/v2.0 --os-region-name='regionTwo' --os-tenant-name="${tenant_name}" --os-username="${user_name}" --os-password="${user_passwd}" download "${container_name}" --prefix "${object_name}"
             var_retval=$?
             [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: retval status is ${var_retval} , swfit session had an error." >> ${log_dir}
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: backup directory is ${backup_dir} , container is ${container_name} , object is ${object_name}  , download file session end." >> ${log_dir}
            elif [ ! -z ${container_name} ] && [ -z ${object_name} ]; then
            cd ${backup_dir}
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: backup directory is ${backup_dir} , container is ${container_name} , object is NONE , download file session starting." >> ${log_dir}
             /usr/bin/swift -V 2 -A http://127.0.0.1:5000/v2.0 --os-region-name='regionTwo' --os-tenant-name="${tenant_name}" --os-username="${user_name}" --os-password="${user_passwd}" download "${container_name}"
             var_retval=$?
             [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: retval status is ${var_retval} , swfit session had an error." >> ${log_dir}
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: backup directory is ${backup_dir} , container is ${container_name} , object is NONE , download file session end." >> ${log_dir}
            else
             echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: backup directory is ${backup_dir} , container is ${container_name} , object is ${object_name} , container or object had an error." >> ${log_dir}
         fi
     fi
    done < ${backup_config_path}

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: End Swift backup scripts." >> ${log_dir}
