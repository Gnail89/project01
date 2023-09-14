#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
container_name="$1"
save_dir="$2"
data_list="$3"
step=20


[ ! -r "${data_list}" ] && echo "${data_list} data list not found" && exit
[ ! -d "${save_dir}/${container_name}" ] && echo "${save_dir}/${container_name} data path not found" && exit

FifoFile="$$.fifo"
mkfifo $FifoFile
exec 6<>$FifoFile
rm $FifoFile
for ((i=0;i<=${step};i++));do echo;done >&6
while read line;do
    read -u6
    {
        if [ -r "${save_dir}/${container_name}/${line}" ]; then
            echo "start upload: ${save_dir}/${container_name}/${line}"
            aws s3 cp "${save_dir}/${container_name}/${line}" s3://bucket/${container_name}/
        else
            echo "upload failed: ${save_dir}/${container_name}/${line}"
        fi
        sleep 0
        echo >&6
    } &
done < ${data_list}
wait
exec 6>&-
