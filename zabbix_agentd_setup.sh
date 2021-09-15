#!/bin/bash

export PATH="/bin:/usr/bin:/sbin:/usr/sbin"

function help_info(){
    echo "
Usage:
    $0 -s ipaddr
    $0 [-u user_name] -s ipaddr
    $0 [-u user_name] [-d directory] -s ipaddr
Options:
    -u user_name
                Which user to install program, default value: 'cloud'
    -d directory
                The top of the installation directory, default value: '\$HOME'
    -s ipaddr
                Server/Proxy IP address
    "
}

function init_paras(){
    local self=("$@")
    serverIP=""
    targetUser="cloud"
    rootPath="/home/cloud"
    for ((i=0;i<${#self[@]};i++));do
        case "${self[i]}" in
            -s)
                n=$(( i + 1 ))
                serverIP="${self[n]}"
                ;;
            -u)
                n=$(( i + 1 ))
                targetUser="${self[n]}"
                ;;
            -d)
                n=$(( i + 1 ))
                rootPath="${self[n]}"
                ;;
            -h)
                help_info
                exit 0
                ;;
        esac
    done
    srcFilename="zabbix_agentd_static.tar.gz"
    resServers="172.17.1.1:8080 172.16.2.1:8080"
    instDirName="${rootPath}/zabbix_agentd"
    daemonScript="${rootPath}/zabbix_agentd/zabbix_script.sh"
    cronPolicy="*/10 * * * * /bin/sh ${rootPath}/zabbix_agentd/zabbix_script.sh daemon 2>&1 >/dev/null"
    configFile="${rootPath}/zabbix_agentd/etc/zabbix_agentd.conf"
    userParameterPath="${rootPath}/zabbix_agentd/etc/zabbix_agentd.conf.d"
}

function get_os_version(){
    hw_name="$(uname -m)"
    kernel_name="$(uname -s)"
}

function download_package(){
    for host in ${resServers};do
        curl -s -m 5 --connect-timeout 2 -o "${srcFilename}" http://${host}/path/${srcFilename}
        [ $? -eq 0 ] && break || rm -f "${srcFilename}"
    done
}

function add_cron_policy(){
    if [ "$(crontab -l |egrep -v "^#|^$" |egrep -c "${daemonScript}")" -eq 0 ]; then
        echo "$(crontab -l)" |sed "1i\\${cronPolicy}" |crontab
    fi
}

function decompress_packages(){
    if [ -r "${srcFilename}" ]; then
        tar -zxf ${srcFilename}
    else
        echo "${srcFilename} file not found"
        exit 1
    fi
}

function get_defroute_ipaddr(){
    local ifname="$(route -n |egrep "^0\.0\.0\.0" |awk '{print $NF}')"
    if [ x"${ifname}" != x"" ]; then
        hostIP="$(ip addr show dev ${ifname} |egrep -o "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" |sed -n "1p")"
    else
        echo "Failed to get local host IP, please enter ip:"
        read -t 30 -p "Local Host IP: " -n 64 hostIP
    fi
}

function modify_configfile(){
    if [ -w "${configFile}" ]; then
        sed -i "s#%change_hostname%#${hostIP}#g" ${configFile}
        sed -i "s#%change_serverip%#${serverIP}#g" ${configFile}
        sed -i "s#%change_basepath%#${instDirName}#g" ${configFile}
    fi
    if [ -w "${daemonScript}" ]; then
        sed -i "s#%change_basepath%#${instDirName}#g" ${daemonScript}
    fi
    if [ -d "${userParameterPath}" ]; then
        find ${userParameterPath} -type f 2>/dev/null |while read line;do
            sed -i "s#%change_basepath%#${instDirName}#g" ${line}
        done
    fi
}

function main(){
    if [ x"$(whoami)" != x"root" ]; then
        init_paras "$@"
        get_defroute_ipaddr
        [ x"${hostIP}" == x"" ] && echo "Get host ip failed" && exit 1
        if [ -r "${srcFilename}" ]; then
            [ x"${serverIP}" == x"" ] && echo "zabbix server ip is NULL" && exit 1
            decompress_packages
            modify_configfile
            add_cron_policy
            echo 'Completed.'
        else
            [ x"${serverIP}" == x"" ] && echo "zabbix server ip is NULL" && exit 1
            download_package
            decompress_packages
            modify_configfile
            add_cron_policy
            echo 'Completed.'
        fi
    else
        echo "root user is not allowed"
        exit 1
    fi
}

main "$@"
