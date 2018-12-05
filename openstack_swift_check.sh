#!/bin/bash

check_type=$1
log_dir="/tmp/swift_check.log"
var_count=''
var_retval=''

ck_keepalived() {
    var_count=`ps -ef |grep keepalived |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , Keepalived process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , Keepalived process Error."
    fi
}

ck_keystone() {
    var_count=`ps -ef |grep keystone |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , keystone process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , keystone process Error."
    fi
}

ck_dossapp() {
    if [ -f /bin/netstat ]; then
         var_count=`/bin/netstat -ntl |grep ':8080' |grep -v grep |wc -l`
         if [ ${var_count} -gt 0 ]; then
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , doss_app port OK."
            else
             echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , doss_app port Error."
         fi
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , netstat command not found. doss_app port check failed."
    fi
}

ck_memcached() {
    var_count=`ps -ef |grep memcached |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , memcached process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , memcached process Error."
    fi
}

ck_swift_proxy_server() {
    var_count=`ps -ef |grep proxy-server |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , proxy-server process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , proxy-server process Error."
    fi
}

ck_rsync() {
    if [ -f /bin/netstat ]; then
         var_count=`/bin/netstat -ntl |grep ':873' |grep -v grep |wc -l`
         if [ ${var_count} -gt 0 ]; then
             echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , rsync port OK."
            else
             echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , rsync port Error."
         fi
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , netstat command not found. rsync port check failed."
    fi
}

# check swift_object service
ck_swift_object_server() {
    var_count=`ps -ef |grep object-server |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , object-server process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , object-server process Error."
    fi
}

ck_swift_object_replicator() {
    var_count=`ps -ef |grep object-replicator |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , object-replicator process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , object-replicator process Error."
    fi
}

ck_swift_object_updater() {
    var_count=`ps -ef |grep object-updater |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , object-updater process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , object-updater process Error."
    fi
}

ck_swift_object_auditor() {
    var_count=`ps -ef |grep object-auditor |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , object-auditor process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , object-auditor process Error."
    fi
}

# check swift-container service
ck_swift_container_server() {
    var_count=`ps -ef |grep container-server |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , container-server process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , container-server process Error."
    fi
}

ck_swift_container_replicator() {
    var_count=`ps -ef |grep container-replicator |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , container-replicator process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , container-replicator process Error."
    fi
}

ck_swift_container_updater() {
    var_count=`ps -ef |grep container-updater |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , container-updater process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , container-updater process Error."
    fi
}

ck_swift_container_auditor() {
    var_count=`ps -ef |grep container-auditor |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , container-auditor process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , container-auditor process Error."
    fi
}

# check swift-account service
ck_swift_account_server() {
    var_count=`ps -ef |grep account-server |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , account-server process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , account-server process Error."
    fi
}

ck_swift_account_replicator() {
    var_count=`ps -ef |grep account-replicator |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , account-replicator process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , account-replicator process Error."
    fi
}

ck_swift_account_reaper() {
    var_count=`ps -ef |grep account-reaper |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , account-reaper process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , account-reaper process Error."
    fi
}

ck_swift_account_auditor() {
    var_count=`ps -ef |grep account-auditor |grep -v grep |wc -l`
    if [ ${var_count} -gt 0 ]; then
         echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , account-auditor process OK."
        else
         echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Host is ${HOSTNAME} , account-auditor process Error."
    fi
}

# check filesystem usage
ck_filesystem() {
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , filesystem free < 25%."
    echo "`df -hP |awk '+$5 > 75'`"
}

# check swift disk usage
ck_swift_disk_usage() {
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Host is ${HOSTNAME} , swift disk usage."
    echo "`swift-recon -d --human-readable`"
}

# group list
grp_manage_server() {
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift manage server checking start  ==="
     ck_keepalived
     ck_keystone
     ck_dossapp
     ck_filesystem
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift manage server checking ended  ==="
}

grp_proxy_server() {
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift proxy server checking start  ==="
     ck_swift_disk_usage
     ck_keepalived
     ck_memcached
     ck_swift_proxy_server
     ck_filesystem
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift proxy server checking ended  ==="
}

grp_storage_server() {
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift storage server checking start  ==="
     ck_rsync
     ck_swift_object_server
     ck_swift_object_replicator
     ck_swift_object_updater
     ck_swift_object_auditor
     ck_swift_container_server
     ck_swift_container_replicator
     ck_swift_container_updater
     ck_swift_container_auditor
     ck_swift_account_server
     ck_swift_account_replicator
     ck_swift_account_auditor
     ck_swift_account_reaper
     ck_filesystem
     echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ====  swift storage server checking ended  ==="
}

# main
case ${check_type} in
     manage)
         grp_manage_server
         ;;
     proxy)
         grp_proxy_server
         ;;
     storage)
         grp_storage_server
         ;;
     *)
         echo -e $"\nUsage: $0 {manage|proxy|storage}\n"
         ;;
esac
