#!/bin/bash

basepath="$(cd `dirname $0`;pwd)"
swift_cmd="$(which swift)"
data_dir="/data"
container_name=""
tenant_name=""
user_name=""
user_pwd=""
auth_url="http://172.16.1.1:5000/v2.0"
token_str=""
storage_url=""
object_file="${basepath}/${tenant_name}_${container_name}_object_list.txt"
failed_file="${basepath}/${tenant_name}_${container_name}_object_fail_${object_file}_$(date "+%Y%m%d%H%M%S").txt"
log_file="${basepath}/${tenant_name}_${container_name}_object_${object_file}_$(date "+%Y%m%d%H%M%S").log"


token_update(){
    local self="$(${swift_cmd} -V 2 -A ${auth_url} --os-tenant-name="${tenant_name}" --os-username="${user_name}" --os-password="${user_pwd}" stat -v)"
    token_str="$(echo "${self}" |grep "Token:" |awk '{print $NF}')"
    storage_url="$(echo "${self}" |grep "StorageURL:" |awk '{print $NF}')"
}


download_pr(){
    local self="$1"
    ${swift_cmd} --os-storage-url="${storage_url}" --os-auth-token="${token_str}" download "${container_name}" "${self}" 2>&1
}


get_obj_list(){
    ${swift_cmd} -V 2 -A ${auth_url} --os-tenant-name="${tenant_name}" --os-username="${user_name}" --os-password="${user_pwd}" list "${container_name}" > ${object_file}
}


swift_worker(){
    [ ! -d "${data_dir}/${container_name}" ] && mkdir -p "${data_dir}/${container_name}"
    cd "${data_dir}/${container_name}"
    while read obj_name; do
        local tmp="$(download_pr "${obj_name}")"
        local ret=$?
        if [ $(echo "${tmp}" |grep -ic "401 Unauthorized") -ne 0 ]; then
            token_update
            sleep 1
            # download again
            local tmp1="$(download_pr "${obj_name}")"
            local ret1=$?
            if [ $(echo "${tmp1}" |grep -ic "401 Unauthorized") -ne 0 ]; then
                echo "ERROR: get token failed, object name: ${obj_name}"
                echo "${obj_name}" >> ${failed_file}
                exit 0
            elif [ ${ret1} -ne 0 ]; then
                echo "${obj_name}" >> ${failed_file}
            else
                echo "${tmp1}" >> ${log_file}
            fi
        elif [ ${ret} -ne 0 ]; then
            echo "${obj_name}" >> ${failed_file}
        else
            echo "${tmp}" >> ${log_file}
        fi
    done < ${object_file}
}


main(){
    if [ -d "${data_dir}" ]; then
        [ -r "${object_file}" ] && echo "file ${object_file} not found" && exit 0
        cat /dev/null > ${failed_file}
        cat /dev/null > ${object_file}
        get_obj_list
        token_update
        if [ x"${token_str}" != x"" ] && [ x"${storage_url}" != x"" ]; then
            swift_worker
        else
            echo "ERROR: first get token failed"
        fi
    else
        echo "save data path not found"
    fi
}

main
