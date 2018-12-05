#!/bin/bash

basepath=$(cd `dirname $0`;pwd)
date_filter="$(date -d '1 day ago' +'%Y-%m-%d')"
data_save_path="${basepath}/data"
data_analysis_path="${data_save_path}/swift_log_analysis_${date_filter}.txt"
data_source_file="/tomcat/logs/localhost_access_log.${date_filter}.txt"

if [ ! -f ${data_source_file} ]; then
  exit 1
fi
if [ ! -d ${data_save_path} ]; then
  exit 1
fi

grep 'iaas/openstack/swift/object/upload' ${data_source_file} |awk '{ary[$1]++} END {for(key in ary) print "source ip: " key " : uploads: " ary[key]}' >> ${data_analysis_path}
grep 'iaas/openstack/swift/object/download' ${data_source_file} |awk '{ary[$1]++} END {for(key in ary) print "source ip: " key " : downloads: " ary[key]}' >> ${data_analysis_path}
grep 'iaas/openstack/swift/object/deleteByObject' ${data_source_file} |awk '{ary[$1]++} END {for(key in ary) print "source ip: " key " : deleteByObject: " ary[key]}' >> ${data_analysis_path}
grep 'iaas/openstack/swift/object/list' ${data_source_file} |awk '{ary[$1]++} END {for(key in ary) print "source ip: " key " : list: " ary[key]}' >> ${data_analysis_path}
