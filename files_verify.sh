#!/bin/bash

scan_dirs=('/usr' '/var')

basepath=$(cd `dirname $0`;pwd)
data_file="${basepath}/data.db"
data_hash="${basepath}/.data.db.hash"
data_tmp="${basepath}/data.tmp"
ignore_size="50M"

cmd_md5="`which md5sum`"


help_msg(){
    echo "
Usage:
    $0 init
    $0 scan
    $0 -h
Options:
    init
            Initialize the environment, first run.
    scan
            Scan files.
    "
}

init_jobs(){
    echo -n "Initialize the directory and generate the hash table"
    find ${scan_dirs[@]} -type f -size -${ignore_size:-50M} 2>/dev/null |xargs -i ${cmd_md5} {} |sort > ${data_file}
    echo "      [ complete ]"
    echo -n "Get hash data for ${data_file}"
    if [ -r ${data_file} ]; then
        ${cmd_md5} ${data_file} |awk '{print $1}' > ${data_hash}
        echo "      [ complete ]"
    else
        echo "      [ Error ]"
        echo "${data_file} file not found"
    fi
}

verify_data(){
    if [ -r ${data_file} ] && [ -r ${data_hash} ]; then
        if [ x"$(${cmd_md5} ${data_file} |awk '{print $1}')" != x"$(cat ${data_hash})" ]; then
            echo "Failed, hash broken"
            exit 0
        fi
    else
        echo "Failed, data & hash not found"
        exit 0
    fi
}

scan(){
    echo "Loading data" && verify_data
    echo "Start Scanning"
    find ${scan_dirs[@]} -type f -size -${ignore_size:-50M} 2>/dev/null |xargs -i ${cmd_md5} {} |sort > ${data_tmp}
    local t1="${basepath}/.tmp1"
    local t2="${basepath}/.tmp2"
    verify_data
    if [ -r "${data_file}" ]; then
        cat ${data_file} |awk '{print $1}' > ${t1}
    fi
    if [ -r "${data_tmp}" ]; then
        cat ${data_tmp} |awk '{print $1}' > ${t2}
    fi
    if [ -r "${t1}" ] && [ -r "${t2}" ]; then
        if [ x"$(${cmd_md5} ${t1} |awk '{print $1}')" != x"$(${cmd_md5} ${t2} |awk '{print $1}')" ]; then
            echo "Critical, Found File changes, Exporting"
            local t3="${basepath}/.tmp3"
            cat /dev/null > ${t3}
            for i in $(diff ${t1} ${t2} |egrep "^<|^>" |awk '{print $2}'); do
                echo "Suspicious file: $(grep "${i}" ${data_file} ${data_tmp} |awk '{print $NF}')" >> ${t3}
            done
            echo "$(cat ${t3} |sort |uniq)"
        else
            echo "OK, All Files Healthy"
        fi
    else
        echo "Failed cache files"
        exit 0
    fi
    [ -f "${t1}" ] && rm -f "${t1}"
    [ -f "${t2}" ] && rm -f "${t2}"
    [ -f "${t3}" ] && rm -f "${t3}"
    [ -f "${data_tmp}" ] && rm -f "${data_tmp}"
}

main(){
    case $1 in
        init)
            init_jobs
            ;;
        scan)
            scan
            ;;
        *)
            help_msg
            ;;
    esac
}

main "$1"
