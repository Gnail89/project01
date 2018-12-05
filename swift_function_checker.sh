#!/usr/bin/env bash

basepath=$(cd `dirname $0`;pwd)
temp_dir="${basepath}/temp"
log_dir="${basepath}/swift_function_checker.log"
result_file="${basepath}/result_check.txt"
lock_file="${basepath}/socket.lock"
check_vars=10
var_retval=''

if [ ! -d ${temp_dir} ];then
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${temp_dir} directory not found." >> ${log_dir}
     exit 1
fi

if [ ! -f /usr/bin/swift ];then
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: /usr/bin/swift command not found." >> ${log_dir}
     exit 1
fi

function clean_temp() {
  if [[ -d ${temp_dir} ]]; then
    find ${temp_dir} -type f |xargs rm -f {}
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: erase temp data." >> ${log_dir}
  fi
}

function kill_process() {
  main_pid=${1}
  if [[ $(ps -ef |grep -w "${main_pid}" |grep -v "grep" |wc -l) -gt 1 ]]; then
    for child_pid in $(ps -ef |grep -w "${main_pid}" |grep -v "grep" |awk '{print $2}'); do
      if [[ ! -z ${child_pid} ]] && [[ x${child_pid} != x${main_pid} ]]; then
        if [[ $(ps -ef |grep -w "${child_pid}" |grep -v "grep" |wc -l) -eq 1 ]]; then
          kill -9 "${child_pid}"
          echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: kill Process: ${child_pid}." >> ${log_dir}
        elif [[ $(ps -ef |grep -w "${child_pid}" |grep -v "grep" |wc -l) -gt 1 ]]; then
          kill_process "${child_pid}"
        fi
      fi
    done
  fi
}

function download_object() {
  cd ${temp_dir}
  var_retval=$?
if [[ ${var_retval} -eq 0 ]]; then
  var_temp=${1}
  /usr/bin/swift -V 2 -A http://127.0.0.1:5000/v2.0 \
  --os-region-name='regionTwo' \
  --os-tenant-name="${tenant_name}" \
  --os-username="${user_name}" \
  --os-password="${user_passwd}" \
  download --output="${temp_dir}/test${var_temp}" "${container_name}" "${object_name}"
else
  echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch ${temp_dir} was failed." >> ${log_dir}
fi
}

function checker() {
  var_counts=$(find ${temp_dir} -type f |wc -l)
  if [[ ${var_counts} -eq ${check_vars} ]]; then
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Result: OK , Current Counts: ${var_counts}" >> ${log_dir}
    echo "Result: OK , Current Counts: ${var_counts}" > ${result_file}
  else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Result: FAILED , Current Counts: ${var_counts}" >> ${log_dir}
    echo "Result: FAILED , Current Counts: ${var_counts}" > ${result_file}
  fi
}

if [[ ! -f ${lock_file} ]]; then
  echo "$$" > ${lock_file}
  clean_temp
  for (( i = 0; i < ${check_vars}; i++ )); do
    {
      download_object "${i}"
    } &
  done
  sleep ${check_vars}
  checker
  kill_process "$$"
  clean_temp
  rm -f ${lock_file}
else
  echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: $0 is running." >> ${log_dir}
fi
