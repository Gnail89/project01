#!/bin/bash

tenant_name=""
user_name=""
user_pass=""
account_id=""
container_name=""
tokenid=""
marker_id=""
ret=0

while read line; do
    echo "start pull container: $line object list"
    container_name="$(echo ${line} |sed "s/ //g")"
    while true ;do
        log_file="${container_name}.log"
        [ ! -f ${log_file} ] && touch ${log_file}
        curr=$(tail -n 1 ${log_file})
        if [ $(echo "${curr}" |grep "This server could not verify that you are authorized to access the document you requested" |wc -l) -ne 0 ] || [ x"${curr}" == x"" ] || [ x"${tokenid}" == x"" ]; then
            tokenid=$(curl -X POST -H "Content-Type:application/json" -d "{\"auth\":{\"tenantName\":\"${tenant_name}\",\"passwordCredentials\":{\"username\":\"${user_name}\",\"password\":\"${user_pass}\"}}}" http://1.1.1.1:5000/v2.0/tokens |python -c "import sys, json; print(json.load(sys.stdin)['access']['token']['id'])")
            sed -i "/This server could not verify that you are authorized to access the document you requested/d" ${log_file}
            curr=$(tail -n 1 ${log_file})
        fi
        if [ $(echo "${curr}" |grep "The resource could not be found" |wc -l) -ne 0 ]; then
            sed -i "/The resource could not be found/d" ${log_file}
            curr=$(tail -n 1 ${log_file})
            ret=1
        fi
        if [ x"${marker_id}" == x"" ]; then
            marker_id="${curr}"
            curl -X GET -H "Content-Type:application/json" -H "X-Auth-Token:${tokenid}" http://1.1.1.1:8888/v1/${account_id}/${container_name}?marker=${marker_id} >> ${log_file}
        elif [ x"${marker_id}" != x"${curr}" ] && [ $(echo "${curr}" |grep "This server could not verify that you are authorized to access the document you requested" |wc -l) -eq 0 ]; then
            marker_id="${curr}"
            curl -X GET -H "Content-Type:application/json" -H "X-Auth-Token:${tokenid}" http://1.1.1.1:8888/v1/${account_id}/${container_name}?marker=${marker_id} >> ${log_file}
        elif [ x"${marker_id}" == x"${curr}" ] && [ ${ret} -eq 1 ]; then
            marker_id="${curr}"
            curl -X GET -H "Content-Type:application/json" -H "X-Auth-Token:${tokenid}" http://1.1.1.1:8888/v1/${account_id}/${container_name}?marker=${marker_id} >> ${log_file}
            ret=0
        else
            break
        fi
    done
    echo "end pull container: $line object list"
done < container_list.txt
