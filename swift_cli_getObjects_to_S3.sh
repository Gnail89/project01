#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
save_dir="/data"
step=1000

while read line; do
    echo "goto [ ${line} ] container"
    if [ x"$(echo "${line}" |egrep -v "^#|^$")" != x"" ]; then
        container_name="${line}"
    else
        echo "none str in container name"
        break
    fi
    
    data_file="${basepath}/${container_name}.txt"
    echo "load list file: ${data_file}"
    
    if [ -r ${data_file} ]; then
        max_n="$(wc -l ${data_file} |awk '{print $1}')"
        max_n=$(( $max_n + $step ))
    else
        echo "data file read fail"
        break
    fi
    
    [ ! -d ${save_dir}/${container_name} ] && mkdir -p ${save_dir}/${container_name}
    
    for ((n=0;n<=${max_n};n+=${step}));do
        n_start=$(( $n + 1 ))
        n_stop=$(( $n + $step ))
        file_names="$(sed -n "${n_start},${n_stop}p" ${data_file})"
        if [ x"$(echo $file_names |sed "s/[[:space:]]//g")" != x"" ]; then
            echo "start download from swift, start: ${n_start} , stop: ${n_stop}"
            cd ${save_dir}/${container_name}
            swift -V 2 -A http://1.1.1.1:5000/v2.0 -U user:name -K pass download ${container_name} $(echo $file_names)
            echo "end download from swift, start: ${n_start} , stop: ${n_stop}"
        fi
        
        if [ x"$(echo $file_names |sed "s/[[:space:]]//g")" != x"" ]; then
            cd ${save_dir}/${container_name}
            for i in $(echo $file_names);do
                if [ -f ${i} ]; then
                    echo "start upload to HDS, file name: ${i}"
                    {
                    aws s3 cp ${i} s3://nonpaper/${container_name}/
                    } &
                    sleep 0
                    echo "end upload to HDS, file name: ${i}"
                fi
            done
        fi
    done
done < $1
