#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
swift_user_info_file="${basepath}/swift_user_info.conf"
swift_bk_blacklist_file="${basepath}/swift_black_list.conf"
swift_bk_config_file="${basepath}/swift_backup_list_final.conf"
single_tenant_info_newest="${basepath}/swift_tenant_info.newest"
swift_tenant_info_lastest="${basepath}/swift_tenant_info.lastest"
swift_bk_data_dir="/data"
tenant_info_tempfile="${basepath}/tenant_info_tempfile"
diff_data_tempfile="${basepath}/diff_data_tempfile"
log_dir="${basepath}/swift_analysis.log"
secret_key=$1
var_retval=''

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start Automatic Analysis Difference." >> ${log_dir}

if [ ! -f ${swift_user_info_file} ];then
  echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_user_info_file} file not found." >> ${log_dir}
  exit 1
fi
if [ -f ${tenant_info_tempfile} ]; then
  cat /dev/null > ${tenant_info_tempfile}
fi
if [ -f ${swift_bk_config_file} ]; then
  cat /dev/null > ${swift_bk_config_file}
fi
if [ ! -f ${single_tenant_info_newest} ]; then
  cat /dev/null > ${single_tenant_info_newest}
fi
if [ ! -f ${swift_bk_blacklist_file} ]; then
  cat /dev/null > ${swift_bk_blacklist_file}
fi

checkEnvironmentStat(){
  if [ ! -r ${swift_user_info_file} ];then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_user_info_file} file can not access." >> ${log_dir}
    exit 1
  fi
  if [ ! -d ${swift_bk_data_dir} ];then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_bk_data_dir} directory not found." >> ${log_dir}
    exit 1
  fi
  if [ ! -f /usr/bin/swift ];then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: /usr/bin/swift command not found." >> ${log_dir}
    exit 1
  fi
  if [ ! -f ${swift_tenant_info_lastest} ]; then
    cat /dev/null > ${swift_tenant_info_lastest}
  fi
  if [ -f ${single_tenant_info_newest} ]; then
    cat /dev/null > ${single_tenant_info_newest}
  fi
  if [ -f ${diff_data_tempfile} ]; then
    cat /dev/null > ${diff_data_tempfile}
  fi
}

getTenantInfo(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: get tenant info start." >> ${log_dir}
    if [ ! -z ${tenant_name} ] && [ ! -z ${user_name} ] && [ ! -z ${user_pwd} ]; then
      /usr/bin/swift -V 2 -A http://127.0.0.1:35357/v2.0 -U ${tenant_name}:${user_name} -K ${user_pwd} list 2>/dev/null |awk '{print "'"${tenant_name}"'""|"$0"|"}' |while read line; do
        local temp_container_name=`echo $line |awk -F '|' '{print $2}'`
        /usr/bin/swift -V 2 -A http://127.0.0.1:35357/v2.0 -U ${tenant_name}:${user_name} -K ${user_pwd} stat ${temp_container_name} 2>/dev/null |awk 'NR>2 && NR<4' |awk '{print "'"${tenant_name}"'""|""'"${temp_container_name}"'""|"$2"|"}' >> ${single_tenant_info_newest}
      done
      var_retval=$?
      [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: retval status is ${var_retval} , pull ${tenant_name} tenant info failed , an error has occurred." >> ${log_dir}
      swapTenantInfo
    else
      echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: pull ${tenant_name} tenant info failed." >> ${log_dir}
    fi
}

swapTenantInfo(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: swap tenant information start." >> ${log_dir}
  if [ ! -z ${single_tenant_info_newest} ]; then
    cat ${single_tenant_info_newest} >> ${tenant_info_tempfile}
  else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${single_tenant_info_newest} transfer was failed, an error has occurred." >> ${log_dir}
  fi
}

compareTenantBKStatus(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: tenant status compare start." >> ${log_dir}
  if [ -f ${single_tenant_info_newest} ] && [ -f ${swift_tenant_info_lastest} ]; then
    grep -vwf ${swift_tenant_info_lastest} ${single_tenant_info_newest} >> ${diff_data_tempfile}
  else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${single_tenant_info_newest} and ${swift_tenant_info_lastest} files not found." >> ${log_dir}
  fi
}

updateTenantProfile(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: create backup profile start." >> ${log_dir}
  while read diff_data_tempfile_str; do
    if [ ! -z `echo ${diff_data_tempfile_str} |sed '/^#/d' |sed '/^$/d'` ]; then
      local temp_tenant_name=`echo ${diff_data_tempfile_str} |awk -F '|' '{print $1}'`
      local temp_container_name=`echo ${diff_data_tempfile_str} |awk -F '|' '{print $2}'`
      if [ ! -z ${temp_tenant_name} ] && [ ! -z ${temp_container_name} ] && [ ${tenant_name} == ${temp_tenant_name} ]; then
        echo "${tenant_name}|${user_name}|${user_pwd}|${swift_bk_data_dir}/${tenant_name}|${temp_container_name}|" >> ${swift_bk_config_file}
      else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Failed to check parameters . tenant name is ${tenant_name} , swap tenant name is ${temp_tenant_name} , swap container name is ${temp_container_name} ." >> ${log_dir}
      fi
    fi
  done < ${diff_data_tempfile}
}

updateLastTenantInfo(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: update lastest tenant infomation start." >> ${log_dir}
  if [ -f ${tenant_info_tempfile} ]; then
    cat ${tenant_info_tempfile} > ${swift_tenant_info_lastest}
  else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${tenant_info_tempfile} transfer was failed, an error has occurred." >> ${log_dir}
  fi
}

blackListAudit(){
  echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: black list checking start." >> ${log_dir}
    if [ -f ${single_tenant_info_newest} ] && [ -f ${swift_bk_blacklist_file} ]; then
      while read line; do
        if [ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]; then
          # black list infomation format: ${blacklist_tenant_name}|${blacklist_container_name}|
          local blacklist_tenant_name=`echo $line |awk -F '|' '{print $1}'`
          local blacklist_container_name=`echo $line |awk -F '|' '{print $2}'`
          if [ $(grep "${blacklist_tenant_name}|${blacklist_container_name}|" ${single_tenant_info_newest} |wc -l) -ne 0 ]; then
            sed -i "#${blacklist_tenant_name}|${blacklist_container_name}|#d" ${single_tenant_info_newest}
          fi
        fi
      done < ${swift_bk_blacklist_file}
    else
      echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_bk_blacklist_file} file not found." >> ${log_dir}
    fi
}

while read line; do
  if [ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]; then
    line=$(echo ${line} |openssl aes-256-cbc -d -k ${secret_key} -base64)
    checkEnvironmentStat
    # user information format: ${tenant_name}|${user_name}|${user_pwd}|
    tenant_name=`echo $line |awk -F '|' '{print $1}'`
    user_name=`echo $line |awk -F '|' '{print $2}'`
    user_pwd=`echo $line |awk -F '|' '{print $3}'`
    if [ ! -z ${tenant_name} ] && [ ! -z ${user_name} ] && [ ! -z ${user_pwd} ]; then
      getTenantInfo
      blackListAudit
      compareTenantBKStatus
      updateTenantProfile
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Failed to check parameters . tenant name is ${tenant_name} , user name is ${user_name} ." >> ${log_dir}
    fi
  fi
done < ${swift_user_info_file}
updateLastTenantInfo
echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: End Automatic Analysis Difference." >> ${log_dir}
