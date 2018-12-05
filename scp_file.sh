#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
log_dir="${basepath}/log.log"
var_retval='0'
hostip="1.1.1.1"
userid="user"
passwd="pass"
src_filename="filename_$(date +'%Y%m%d').tar.gz"
src_path="/opt/path"
dest_path="/home/user/"
save_path="/data/path"

if [ -d ${src_path} ]; then
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: tar files ${src_path} starting." >> ${log_dir}
     tar -zcf ${src_filename} -C "${save_path}" "${src_path}/doss" "${src_path}/cloud-united-api"
     var_retval=$?
     [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tar processing status is ${var_retval}" >> ${log_dir}
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: tar files ${src_path} end." >> ${log_dir}
    else
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${src_path} not found." >> ${log_dir}
fi

if [ -f "${save_path}/${src_filename}" ]; then
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: expect script starting , filename is ${save_path}/${src_filename}." >> ${log_dir}
     expect scp_file.exp "${hostip}" "${userid}" "${passwd}" "${save_path}/${src_filename}" "${dest_path}" >>${log_dir}
     var_retval=$?
     [ ${var_retval} -ne 0 ] && echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: expect script status is ${var_retval}" >> ${log_dir}
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: expect script end." >> ${log_dir}
    else
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: scp files ${save_path}/${src_filename} not found." >> ${log_dir}
fi

if [ -f "${save_path}/${src_filename}" ]; then
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: clear files ${save_path}/${src_filename} starting." >> ${log_dir}
     rm -f "${save_path}/${src_filename}"
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: clear files end." >> ${log_dir}
    else
     echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: clear ${save_path}/${src_filename} not found." >> ${log_dir}
fi
