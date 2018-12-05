#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
date_filter="$(date -d '1 day ago' +'%Y-%m-%d')"
date_time_filter="$(date -d '1 day ago' +'%d')/$(date -d '1 day ago' +'%b')/$(date -d '1 day ago' +'%Y')"
data_save_path="${basepath}/data"
data_download_path="${data_save_path}/swift_log_download_${date_filter}.txt"
data_upload_path="${data_save_path}/swift_log_upload_${date_filter}.txt"
data_source_file="/tomcat/logs/localhost_access_log.${date_filter}.txt"
log_dir="${basepath}/swift_log_analysis.log"
hostip="172.16.1.1"
userid="user"
passwd="password"
dest_save_path="/data/swift_log_analysis/"
var_retval=''

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start scripts." >> ${log_dir}
if [ ! -f ${data_source_file} ]; then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${data_source_file} file not found." >> ${log_dir}
    exit 1
fi
if [ ! -d ${data_save_path} ]; then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${data_save_path} file not found." >> ${log_dir}
    exit 1
fi

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Starting CloudAPI log analysis." >> ${log_dir}
FifoFile="$$.fifo"
mkfifo $FifoFile
exec 6<>$FifoFile
rm $FifoFile
Thread=11
for ((i=0;i<=$Thread;i++));do echo;done >&6
for time_hour_value in {00..23};do
    for time_minute_value in {00..59};do
        read -u6
        {
        echo "${date_filter} ${time_hour_value}:${time_minute_value} $(grep "${date_time_filter}:${time_hour_value}:${time_minute_value}" ${data_source_file} |grep 'iaas/openstack/swift/object/download' |wc -l)" >> ${data_download_path}
        echo "${date_filter} ${time_hour_value}:${time_minute_value} $(grep "${date_time_filter}:${time_hour_value}:${time_minute_value}" ${data_source_file} |grep 'iaas/openstack/swift/object/upload' |wc -l)" >> ${data_upload_path}
        echo >&6
        } &
    done
    wait
done
wait
exec 6>&-
echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended CloudAPI log analysis." >> ${log_dir}

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Starting scp target file." >> ${log_dir}
if [ -f ${data_download_path} ]; then
    sed -i "1i\\$(echo "##  The maximum number of downloads: $(sed -e '/^$/d' -e '/^#/d' ${data_download_path} |awk 'NR==1{max=$3;next}{max=max>$3?max:$3}END{print max}')")" {data_download_path}
    expect scp_file.exp "${hostip}" "${userid}" "${passwd}" "${data_download_path}" "${dest_save_path}" >>${log_dir}
    var_retval=$?
    [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: expect script status is ${var_retval}" >> ${log_dir}
else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${data_download_path} file not found." >> ${log_dir}
fi
if [ -f ${data_upload_path} ]; then
    sed -i "1i\\$(echo "##  The maximum number of uploads: $(sed -e '/^$/d' -e '/^#/d' ${data_upload_path} |awk 'NR==1{max=$3;next}{max=max>$3?max:$3}END{print max}')")" {data_upload_path}
    expect scp_file.exp "${hostip}" "${userid}" "${passwd}" "${data_upload_path}" "${dest_save_path}" >>${log_dir}
    var_retval=$?
    [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: expect script status is ${var_retval}" >> ${log_dir}
else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${data_upload_path} file not found." >> ${log_dir}
fi
echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended scp target file." >> ${log_dir}

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended scripts." >> ${log_dir}
