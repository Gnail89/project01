#!/bin/bash

export PATH=/bin:/usr/bin:/usr/sbin:/sbin
basepath=$(cd `dirname $0`;pwd)
ping_cmd="$(which fping 2>/dev/null)"
ping_count=100
ip_list="${basepath}/ip.txt"
result_file="${basepath}/result.txt"


if [ x"${ping_cmd}" != x"" ] && [ -x "${ping_cmd}" ] && [ -r "${ip_list}" ]; then
    ping_result="$(${ping_cmd} -c ${ping_count} -f ${ip_list} 2>&1)"
else
    exit 0
fi

if [ x"${ping_result}" != x"" ]; then
    swap_ping="$(echo "${ping_result}" |awk '
        BEGIN {
            FS=":|,|/|="
            OFS=","
            host="null"
            loss="-1"
            min="-1"
            avg="-1"
            max="-1"
        }
        {
            if (/xmt.rcv/) {
                gsub(/[[:space:]]+/,"")
                gsub("%","")
                host=$1
                loss=$7
                min=$11
                avg=$12
                max=$13
                if (loss == 100) {
                    min="-1"
                    avg="-1"
                    max="-1"
                }
                print "{\"ip\":\""host"\",\"ping_lossrate\":\""loss"\",\"ping_min\":\""min"\",\"ping_avg\":\""avg"\",\"ping_max\":\""max"\"},"
            }
        }
    ')"
else
    exit 0
fi

if [ x"${swap_ping}" != x"" ]; then
    echo "[$(echo ${swap_ping} |sed "s/,$//g")]" > ${result_file}
else
    exit 0
fi
