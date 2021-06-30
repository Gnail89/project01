#!/bin/bash

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
basepath=$(cd `dirname $0`;pwd)

desc_host="$1"

output_file="${basepath}/custom_ping_stat.txt"
ping_count="100"
ping_interval="0.2"
ping_cmd="$(which ping)"

main(){
    if [ x"${desc_host}" != x"" ]; then
        local ret="$(${ping_cmd} -c${ping_count} -i${ping_interval} ${desc_host} |egrep -o "[[:digit:]]+\% packet loss" |egrep -o "[[:digit:]]+")"
        if [ x"${ret}" != x"" ]; then
            echo "${ret}" > ${output_file}
        else
            echo "error" > ${output_file}
        fi
    fi
}

main
