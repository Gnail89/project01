#!/usr/bin/env bash

basepath=$(cd `dirname $0`;pwd)
config_file="${basepath}/check_nics_list.conf"
source_file="/data/filename"
result_file="${basepath}/check_nics.tmp"
var_retval=''

if [ ! -r ${config_file} ]; then
  exit 1
elif [ ! -r ${source_file} ]; then
  exit 1
elif [ -w ${result_file} ]; then
  cat /dev/null > ${result_file}
fi

checker(){
  grep ${HostNicMAC} ${source_file} |grep vmnic |sed -e 's/<[/tr]*>//g' -e 's/<td>//g' -e 's/<\/td>/|/g' |while read line; do
    if [[ x$(echo ${line} |awk -F '|' '{print $6}') != x${HostNicSpeed} ]]; then
      echo "[ ERROR ] , HOST: ${HostName} , MAC: ${HostNicMAC} , DEVICE: $(echo ${line} |awk -F '|' '{print $2}') , Current SPEED: $(echo ${line} |awk -F '|' '{print $6}')" >> ${result_file}
    fi
  done
}

while read line; do
  if [[ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]]; then
    HostName=`echo $line |awk -F '|' '{print $1}'`
    HostNicMAC=`echo $line |awk -F '|' '{print $2}'`
    HostNicSpeed=`echo $line |awk -F '|' '{print $3}'`
    if [[ ! -z ${HostName} ]] && [[ ! -z ${HostNicMAC} ]] && [[ ! -z ${HostNicSpeed} ]]; then
      var_retval="$(grep ${HostNicMAC} ${source_file} |grep vmnic |wc -l)"
      if [ ${var_retval} -eq 1 ]; then
        checker
      elif [ ${var_retval} -gt 1 ]; then
        checker
      elif [ ${var_retval} -eq 0 ]; then
        echo echo "[ ERROR ] , HOST: ${HostName} , MAC: ${HostNicMAC} , the MAC Address does not exist, should be checked." >> ${result_file}
      fi
    fi
  fi
done < ${config_file}
