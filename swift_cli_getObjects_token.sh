#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
container_name="$1"
save_dir="$2"
tenantid=""
tenant_name=""
user_name=""
user_pass=""
keystone_url="http://127.0.0.1:5000"
swift_url="http://127.0.0.1:8888"
container_file="${basepath}/${container_name}.txt"
save_path="${save_dir}/${container_name}"
tokenid=""
nexttime=0
step=1000


if [ x"${container_name}" == x"" ] || [ x"${save_dir}" == x"" ]; then
    echo "args is NULL, failed"
    exit 0
fi

if [ ! -r ${container_file} ]; then
    echo "container file ${container_file} not found"
    exit 0
fi

if [ ! -d ${save_path} ]; then
    mkdir -p ${save_path}
    echo "create save dirname ${save_path}"
fi

get_token(){
    local msg="$(curl -X POST -H "Content-Type:application/json" -d "{\"auth\":{\"tenantName\":\"${tenant_name}\",\"passwordCredentials\":{\"username\":\"${user_name}\",\"password\":\"${user_pass}\"}}}" ${keystone_url}/v2.0/tokens)"
    tokenid="$(echo "${msg}" |python -c "import sys, json; print(json.load(sys.stdin)['access']['token']['id'])")"
    exptime="$(date -d "$(echo "${msg}" |python -c "import sys, json; print(json.load(sys.stdin)['access']['token']['expires'])")" +%s)"
    nexttime="$(( ${exptime} - 600 ))"
}

verify_token(){
    local t="$(date +%s)"
    if [ x"${tokenid}" == x"" ] || [ x"${nexttime}" == x"" ]; then
        get_token
        if [ x"${tokenid}" == x"" ] || [ x"${nexttime}" == x"" ]; then
            echo "get token failed"
            exit 0
        fi
    else
        if [ $t -ge $nexttime ]; then
            get_token
            if [ x"${tokenid}" == x"" ] || [ x"${nexttime}" == x"" ]; then
                echo "renew token failed"
                exit 0
            fi
        fi
    fi
}

main(){
    if [ -d "${save_path}" ]; then
        if [ -r ${container_file} ]; then
            max_n="$(wc -l ${container_file} |awk '{print $1}')"
            max_n=$(( $max_n + $step ))
        else
            echo "data ${container_file} load failed"
            exit 0
        fi
        for ((n=0;n<=${max_n};n+=${step}));do
            verify_token
            n_start=$(( $n + 1 ))
            n_stop=$(( $n + $step ))
            file_names="$(sed -n "${n_start},${n_stop}p" ${container_file})"
            if [ x"$(echo $file_names |sed "s/[[:space:]]//g")" != x"" ]; then
                echo "start download from swift, start: ${n_start} , stop: ${n_stop}"
                cd ${save_path}
                swift --os-auth-token ${tokenid} --os-storage-url ${swift_url}/v1/${tenantid} download ${container_name} $(echo $file_names)
                echo "end download from swift, start: ${n_start} , stop: ${n_stop}"
            fi
        done
    else
        echo "save path not found"
        exit 0
    fi
}

main
