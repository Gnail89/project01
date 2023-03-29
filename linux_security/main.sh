#!/bin/bash

export PATH=/sbin:/bin:/usr/sbin:/usr/bin
basepath=$(cd `dirname $0`;pwd)
release_version=""
release_id=""

diag_os(){
    if [ -r /etc/os-release ]; then
        # rhel [7-8], centos [7-8], sles [12,15], openEuler [20-22], bclinux 22, anolis 8
        source /etc/os-release
        release_version="${ID}"
        release_id="${VERSION_ID%%.*}"
    elif [ -r /etc/SuSE-release ];then
        # sles 11
        release_version="sles"
        release_id="$(egrep "^VERSION[[:space:]]*=" /etc/SuSE-release |awk '{print $NF}')"
    elif [ -r /etc/redhat-release ]; then
        if [ $(egrep -i "^Red[[:space:]]*Hat" /etc/redhat-release |wc -l) -ne 0 ]; then
            # Red Hat 6.5
            release_version="rhel"
            release_id="$(egrep -o "[[:digit:]]+\.[[:digit:]]+" /etc/redhat-release |sed -n "1p" |sed "s/\..*//g")"
        elif [ $(egrep -i "^CentOS" /etc/redhat-release |wc -l) -ne 0 ]; then
            # CentOS 6.5
            release_version="centos"
            release_id="$(egrep -o "[[:digit:]]+\.[[:digit:]]+" /etc/redhat-release |sed -n "1p" |sed "s/\..*//g")"
        else
            echo "Read information failure, VERSION_ID: ${release_version}, ID: ${release_id}"
            exit 0
        fi
    else
        echo "Read information failure, VERSION_ID: ${release_version}, ID: ${release_id}"
        exit 0
    fi
}

main(){
    diag_os
    echo "Current OS information, VERSION_ID: ${release_version}, ID: ${release_id}"
    t="${basepath}/${release_version}${release_id}/main.sh"
    if [ -r "${t}" ]; then
        bash ${t} &> /dev/null
        echo "Complete."
    else
        echo "System not support, VERSION_ID: ${release_version}, ID: ${release_id}"
    fi
}

main
