#!/bin/bash

# OpenStack Swift Ring Modify scripts
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# 1. device_config_path配置规范: action_type|ring_builder_name|region|zone|host|port|device_name|weight|increment_value|
#          action_type: 设备的操作类型,支持 add improve reduce
#    ring_builder_name: ring环的类型,可选项为 account container object
#               region: 域,必须为大于0的正整数
#                 zone: 区,必须为大于0的正整数
#                 host: 设备IP地址
#                 port: ring环对应的服务端口
#          device_name: 设备名称,如:sdb1
#               weight: 权重值,必须为大于0的正整数,当设置为0时被标记为remove设备
#      increment_value: 权重的递增值,必须为大于0的正整数,建议尽量小
#示例:
#   add|account|1|1|172.16.1.100|6002|sdb1|3000|1|
#   add|container|1|1|172.16.1.100|6001|sdb1|3000|1|
#   add|object|1|1|172.16.1.100|6000|sdb1|3000|1|
#
# 2. all_datanode_list配置规范: 存储节点IP地址.
#示例:
#   172.16.1.100
#   172.16.1.101
#   172.16.1.102
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# basepath
basepath=$(cd `dirname $0`;pwd)
# log file
log_dir="${basepath}/swift_ring_modify.log"
# ring host/device information configuration file
device_config_path="${basepath}/swift_ring_config_device.conf"
# all datanode host list
all_datanode_list="${basepath}/swift_datanode_host.conf"
# swift ring files path
swift_ring_path="/etc/swift"
# openstack swift account.builder file
swift_account_builder="account.builder"
# openstack swift account ring.gz file
swift_account_ring_file="${swift_ring_path}/account.ring.gz"
# openstack swift container.builder file
swift_container_builder="container.builder"
# openstack swift container ring.gz file
swift_container_ring_file="${swift_ring_path}/container.ring.gz"
# openstack swift object.builder file
swift_object_builder="object.builder"
# openstack swift object ring.gz file
swift_object_ring_file="${swift_ring_path}/object.ring.gz"
# openstack swift ring-builder command
swift_ring_builder="/usr/bin/swift-ring-builder"
# time wait value(sec)
sleep_time=3600

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start Swift Ring Modify scripts." >> ${log_dir}
# 检查脚本所需的运行环境
check_files (){
    # 检查设备配置列表文件是否存在
    if [ ! -f ${device_config_path} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${device_config_path} file not found." >> ${log_dir}
        exit 1
    fi
    # 检查存储节点列表文件是否存在
    if [ ! -f ${all_datanode_list} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${all_datanode_list} file not found." >> ${log_dir}
        exit 1
    fi
    # 检查ring配置文件目录是否存在
    if [ ! -d ${swift_ring_path} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_ring_path} path not found." >> ${log_dir}
        exit 1
    fi
    # 检查account.builder是否存在
    if [ ! -f ${swift_ring_path}/${swift_account_builder} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_ring_path}/${swift_account_builder} file not found." >> ${log_dir}
        exit 1
    fi
    # 检查container.builder是否存在
    if [ ! -f ${swift_ring_path}/${swift_container_builder} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_ring_path}/${swift_container_builder} file not found." >> ${log_dir}
        exit 1
    fi
    # 检查object.builder是否存在
    if [ ! -f ${swift_ring_path}/${swift_object_builder} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_ring_path}/${swift_object_builder} file not found." >> ${log_dir}
        exit 1
    fi
    # 检查swift-ring-builder是否存在
    if [ ! -f ${swift_ring_builder} ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_ring_builder} command not found." >> ${log_dir}
        exit 1
    fi
}

# 检查传入参数的合规性
check_parameter (){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start check parameter , parameter is ${ring_device}." >> ${log_dir}
    # 平衡ring环的间隔时间
    if [ ${sleep_time} -lt 3600 ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${sleep_time} value less than 1 hour." >> ${log_dir}
        exit 1
    fi
    # 检查设备操作类型
    if [[ ${action_type} == add ]] || [[ ${action_type} == improve ]] || [[ ${action_type} == reduce ]]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${action_type}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${action_type} , value exception." >> ${log_dir}
        continue
    fi
    # 检查ring环类型
    if [[ ${ring_builder_name} == account ]] || [[ ${ring_builder_name} == container ]] || [[ ${ring_builder_name} == object ]]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${ring_builder_name}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${ring_builder_name} , value exception." >> ${log_dir}
        continue
    fi
    # 检查region值
    if [ "${region_num}" -gt 0 ] 2>/dev/null; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${region_num}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${region_num} , value exception." >> ${log_dir}
        continue
    fi
    # 检查zone值
    if [ "${zone_num}" -gt 0 ] 2>/dev/null; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${zone_num}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${zone_num} , value exception." >> ${log_dir}
        continue
    fi
    # 检查设备IP地址合规性
    if [[ "${host}" =~ ^([0-9]{1,3}.){3}[0-9]{1,3}$ ]]; then
        local FIELD1=$(echo ${host}|cut -d. -f1)
        local FIELD2=$(echo ${host}|cut -d. -f2)
        local FIELD3=$(echo ${host}|cut -d. -f3)
        local FIELD4=$(echo ${host}|cut -d. -f4)
        if [ $FIELD1 -eq 0 -a $FIELD2 -eq 0 -a $FIELD3 -eq 0 -a $FIELD4 -eq 0 ]; then
            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${host} , value exception." >> ${log_dir}
            continue
        fi
        if [ $FIELD1 -le 255 -a $FIELD2 -le 255 -a $FIELD3 -le 255 -a $FIELD4 -le 255 ]; then
            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${host}." >> ${log_dir}
        else
            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${host} , value exception." >> ${log_dir}
            continue
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${host} , value exception." >> ${log_dir}
        continue
    fi
    # 检查IP地址端口
    if [ "${port}" -gt 0 ] 2>/dev/null; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${port}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${port} , value exception." >> ${log_dir}
        continue
    fi
    # 检查设备名称
    if [ ! -z "${device_name}" ]; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${device_name}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${device_name} , null value." >> ${log_dir}
        continue
    fi
    # 检查权重值
    if [ "${weight_num}" -ge 0 ] 2>/dev/null; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${weight_num}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${weight_num} , value exception." >> ${log_dir}
        continue
    fi
    # 检查递增值
    if [ "${increment_value}" -gt 0 ] 2>/dev/null; then
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check parameter ok , value is ${increment_value}." >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${increment_value} , value exception." >> ${log_dir}
        continue
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended check parameter." >> ${log_dir}
}

# 检查search value参数在ring环中的存在情况
check_search_value (){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start check search value, parameter is ${search_value}." >> ${log_dir}
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        # 在account中检查
        if [[ ${ring_builder_name} == account ]]; then
            local value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value1} -eq 0 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check ${swift_account_builder} search value NULL , value is ${search_value}." >> ${log_dir}
            elif [ ${value1} -eq 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_account_builder} search value existing , value is ${search_value}." >> ${log_dir}
            elif [ ${value1} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_account_builder} search value are multiple , value is ${search_value}." >> ${log_dir}
                continue
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: check ${swift_account_builder} search value failed , value is ${search_value}." >> ${log_dir}
                continue
            fi
        fi
        # 在container中检查
        if [[ ${ring_builder_name} == container ]]; then
            local value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value2} -eq 0 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check ${swift_container_builder} search value NULL , value is ${search_value}." >> ${log_dir}
            elif [ ${value2} -eq 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_container_builder} search value existing , value is ${search_value}." >> ${log_dir}
            elif [ ${value2} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_container_builder} search value are multiple , value is ${search_value}." >> ${log_dir}
                continue
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: check ${swift_container_builder} search value failed , value is ${search_value}." >> ${log_dir}
                continue
            fi
        fi
        # 在object中检查
        if [[ ${ring_builder_name} == object ]]; then
            local value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value3} -eq 0 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: check ${swift_object_builder} search value NULL , value is ${search_value}." >> ${log_dir}
            elif [ ${value3} -eq 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_object_builder} search value existing , value is ${search_value}." >> ${log_dir}
            elif [ ${value3} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: check ${swift_object_builder} search value are multiple , value is ${search_value}." >> ${log_dir}
                continue
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: check ${swift_object_builder} search value failed , value is ${search_value}." >> ${log_dir}
                continue
            fi
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended check search value." >> ${log_dir}
}

# ring环文件复制到存储节点
ring_file_copy (){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start Swift ring copy to datanode scripts." >> ${log_dir}
    if [ -f ${swift_account_ring_file} ]; then
        if [ -f ${swift_container_ring_file} ]; then
            if [ -f ${swift_object_ring_file} ]; then
                while read datanode_device
                    do
                    if [ ! -z `echo ${datanode_device} |sed '/^#/d' |sed '/^$/d'` ]; then
                        local var_retval=0
                        datanode_host=`echo $datanode_device |awk '{print $1}'`
                        if [[ ${ring_builder_name} == account ]]; then
                            scp ${swift_account_ring_file} ${datanode_device}:/etc/swift/
                            var_retval=$?
                            if [ ${var_retval} -eq 0 ]; then
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ${swift_account_ring_file} copy ring.gz file to ${datanode_device} successed." >> ${log_dir}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_account_ring_file} copy ring.gz file to ${datanode_device} failed." >> ${log_dir}
                                break
                            fi
                        fi
                        if [[ ${ring_builder_name} == container ]]; then
                            scp ${swift_container_ring_file} ${datanode_device}:/etc/swift/
                            var_retval=$?
                            if [ ${var_retval} -eq 0 ]; then
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ${swift_container_ring_file} copy ring.gz file to ${datanode_device} successed." >> ${log_dir}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_container_ring_file} copy ring.gz file to ${datanode_device} failed." >> ${log_dir}
                                break
                            fi
                        fi
                        if [[ ${ring_builder_name} == object ]]; then
                            scp ${swift_object_ring_file} ${datanode_device}:/etc/swift/
                            var_retval=$?
                            if [ ${var_retval} -eq 0 ]; then
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ${swift_object_ring_file} copy ring.gz file to ${datanode_device} successed." >> ${log_dir}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_object_ring_file} copy ring.gz file to ${datanode_device} failed." >> ${log_dir}
                                break
                            fi
                        fi
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: load datanode host list failed." >> ${log_dir}
                    fi
                done < ${all_datanode_list}
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_object_ring_file} ring.gz files not found." >> ${log_dir}
            fi
        else
            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_container_ring_file} ring.gz files not found." >> ${log_dir}
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${swift_account_ring_file} ring.gz files not found." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended Swift ring copy to datanode scripts." >> ${log_dir}
}

# 修改ring环中设备的权重或平衡环
ring_device_set_weight(){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start modify ring ." >> ${log_dir}
    local action_target=$1
    local action_value=$2
    local weight_value=$3
    local var_retval=0
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        case ${action_value} in
            add|set_weight)
                if [ ! -z ${action_target} ] && [ ! -z ${action_value} ] && [ ! -z ${weight_value} ]; then
                    ${swift_ring_builder} ${action_target} ${action_value} ${search_value} ${weight_value}
                    var_retval=$?
                    if [ ${var_retval} -eq 0 ]; then
                        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ring.builder value is ${action_target} , action value is ${action_value} , search value is ${search_value} , weight value is ${weight_value} , modify device weight to ring file successed." >> ${log_dir}
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ring.builder value is ${action_target} , action value is ${action_value} , search value is ${search_value} , weight value is ${weight_value} , modify device weight to ring file failed." >> ${log_dir}
                        break
                    fi
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: value1 is ${action_target} , value2 is ${action_value} , value3 is ${weight_value} , value reading failed." >> ${log_dir}
                fi
                ;;
            rebalance)
                if [ ! -z ${action_target} ] && [ ! -z ${action_value} ]; then
                    ${swift_ring_builder} ${action_target} ${action_value}
                    var_retval=$?
                    if [ ${var_retval} -eq 0 ]; then
                        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ${action_target} ${action_value} , rebalance ring successed." >> ${log_dir}
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${action_target} ${action_value} , rebalance ring failed." >> ${log_dir}
                        break
                    fi
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: value1 is ${action_target} , value2 is ${action_value} , value reading failed." >> ${log_dir}
                fi
                ;;
            *)
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: value1 is ${action_target} , value2 is ${action_value} , value unrecognized parameters." >> ${log_dir}
                ;;
        esac
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended modify ring ." >> ${log_dir}
}

# 向ring环中新增设备
ring_add_new_device (){
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        if [[ ${ring_builder_name} == account ]]; then
            local value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value1} -eq 0 ]; then
                for (( tmp_weight_value = increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                    value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                    if [ ${value1} -eq 0 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_account_builder} add ${tmp_weight_value}
                            ring_device_set_weight ${swift_account_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_account_builder} add ${weight_num}
                            ring_device_set_weight ${swift_account_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    elif [ ${value1} -eq 1 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_account_builder} set_weight ${tmp_weight_value}
                            ring_device_set_weight ${swift_account_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_account_builder} set_weight ${weight_num}
                            ring_device_set_weight ${swift_account_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
                        break
                    fi
                done
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
                continue
            fi
        elif [[ ${ring_builder_name} == container ]]; then
            local value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value2} -eq 0 ]; then
                for (( tmp_weight_value = increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                    value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                    if [ ${value2} -eq 0 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_container_builder} add ${tmp_weight_value}
                            ring_device_set_weight ${swift_container_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_container_builder} add ${weight_num}
                            ring_device_set_weight ${swift_container_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    elif [ ${value2} -eq 1 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_container_builder} set_weight ${tmp_weight_value}
                            ring_device_set_weight ${swift_container_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_container_builder} set_weight ${weight_num}
                            ring_device_set_weight ${swift_container_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
                        break
                    fi
                done
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
                continue
            fi
        elif [[ ${ring_builder_name} == object ]]; then
            local value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value3} -eq 0 ]; then
                for (( tmp_weight_value = increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                    value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                    if [ ${value3} -eq 0 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_object_builder} add ${tmp_weight_value}
                            ring_device_set_weight ${swift_object_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_object_builder} add ${weight_num}
                            ring_device_set_weight ${swift_object_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    elif [ ${value3} -eq 1 ]; then
                        if [ ${tmp_weight_value} -le ${weight_num} ]; then
                            ring_device_set_weight ${swift_object_builder} set_weight ${tmp_weight_value}
                            ring_device_set_weight ${swift_object_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                            ring_device_set_weight ${swift_object_builder} set_weight ${weight_num}
                            ring_device_set_weight ${swift_object_builder} rebalance
                            ring_file_copy
                            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                            sleep ${sleep_time}
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                            break
                        fi
                    else
                        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
                        break
                    fi
                done
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: add value to ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
                continue
            fi
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
}

# 减少当前设备的权重的方法
ring_reduce_device_weight(){
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        if [[ ${ring_builder_name} == account ]]; then
            local value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value1} -eq 1 ]; then
                local account_current_weight=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${account_current_weight} -gt ${weight_num} ]; then
                    for (( tmp_weight_value = account_current_weight - increment_value ; tmp_weight_value > weight_num - increment_value ; tmp_weight_value -= increment_value )); do
                        value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value1} -eq 1 ]; then
                            if [ ${tmp_weight_value} -ge ${weight_num} ]; then
                                ring_device_set_weight ${swift_account_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_account_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -lt ${weight_num} ]; then
                                ring_device_set_weight ${swift_account_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_account_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${account_current_weight} -lt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
                continue
            fi
        elif [[ ${ring_builder_name} == container ]]; then
            local value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value2} -eq 1 ]; then
                local container_current_weight=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${container_current_weight} -gt ${weight_num} ]; then
                    for (( tmp_weight_value = container_current_weight - increment_value ; tmp_weight_value > weight_num - increment_value ; tmp_weight_value -= increment_value )); do
                        value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value2} -eq 1 ]; then
                            if [ ${tmp_weight_value} -ge ${weight_num} ]; then
                                ring_device_set_weight ${swift_container_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_container_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -lt ${weight_num} ]; then
                                ring_device_set_weight ${swift_container_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_container_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${container_current_weight} -lt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
                continue
            fi
        elif [[ ${ring_builder_name} == object ]]; then
            local value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value3} -eq 1 ]; then
                local object_current_weight=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${object_current_weight} -gt ${weight_num} ]; then
                    for (( tmp_weight_value = object_current_weight - increment_value ; tmp_weight_value > weight_num - increment_value ; tmp_weight_value -= increment_value )); do
                        value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value3} -eq 1 ]; then
                            if [ ${tmp_weight_value} -ge ${weight_num} ]; then
                                ring_device_set_weight ${swift_object_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_object_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -lt ${weight_num} ]; then
                                ring_device_set_weight ${swift_object_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_object_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${object_current_weight} -lt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
                continue
            fi
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
}

# 提高当前设备的权重的方法
ring_improve_device_weight(){
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        if [[ ${ring_builder_name} == account ]]; then
            local value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value1} -eq 1 ]; then
                local account_current_weight=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${account_current_weight} -lt ${weight_num} ]; then
                    for (( tmp_weight_value = account_current_weight + increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                        value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value1} -eq 1 ]; then
                            if [ ${tmp_weight_value} -le ${weight_num} ]; then
                                ring_device_set_weight ${swift_account_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_account_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                                ring_device_set_weight ${swift_account_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_account_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${account_current_weight} -gt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_account_builder} is failed , search value is ${search_value} , value1 is ${value1}." >> ${log_dir}
            fi
        elif [[ ${ring_builder_name} == container ]]; then
            local value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value2} -eq 1 ]; then
                local container_current_weight=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${container_current_weight} -lt ${weight_num} ]; then
                    for (( tmp_weight_value = container_current_weight + increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                        value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value2} -eq 1 ]; then
                            if [ ${tmp_weight_value} -le ${weight_num} ]; then
                                ring_device_set_weight ${swift_container_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_container_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                                ring_device_set_weight ${swift_container_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_container_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${container_current_weight} -gt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_container_builder} is failed , search value is ${search_value} , value2 is ${value2}." >> ${log_dir}
            fi
        elif [[ ${ring_builder_name} == object ]]; then
            local value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value3} -eq 1 ]; then
                local object_current_weight=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep -iv "Device" |awk '{print $9}' |awk -F'.' '{print $1}')
                if [ ${object_current_weight} -lt ${weight_num} ]; then
                    for (( tmp_weight_value = object_current_weight + increment_value ; tmp_weight_value < weight_num + increment_value ; tmp_weight_value += increment_value )); do
                        value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
                        if [ ${value3} -eq 1 ]; then
                            if [ ${tmp_weight_value} -le ${weight_num} ]; then
                                ring_device_set_weight ${swift_object_builder} set_weight ${tmp_weight_value}
                                ring_device_set_weight ${swift_object_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            elif [ ${tmp_weight_value} -gt ${weight_num} ]; then
                                ring_device_set_weight ${swift_object_builder} set_weight ${weight_num}
                                ring_device_set_weight ${swift_object_builder} rebalance
                                ring_file_copy
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start sleep ${sleep_time} ." >> ${log_dir}
                                sleep ${sleep_time}
                            else
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: tmp_weight_value has Exception string , value is ${tmp_weight_value}." >> ${log_dir}
                                break
                            fi
                        else
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
                            break
                        fi
                    done
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: current weight value less than new weight value , ${object_current_weight} -gt ${weight_num} has exception." >> ${log_dir}
                fi
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: change value for ${swift_object_builder} is failed , search value is ${search_value} , value3 is ${value3}." >> ${log_dir}
            fi
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
}

# 检查设备列表在ring环中的存在情况
ring_check_device_list(){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start ring device list check." >> ${log_dir}
    cd ${swift_ring_path}
    local var_retval=$?
    if [ ${var_retval} -eq 0 ]; then
        if [[ ${ring_builder_name} == account ]]; then
            local value1=$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value1} -eq 1 ]; then
                echo "$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep -iv "Device")"
            elif [ ${value1} -eq 0 ]; then
                echo "${search_value} not found."
            elif [ ${value1} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: there are multiple values"
                echo "$(${swift_ring_builder} ${swift_account_builder} search ${search_value} |grep -iv "Device")"
            fi
        elif [[ ${ring_builder_name} == container ]]; then
            local value2=$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value2} -eq 1 ]; then
                echo "$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep -iv "Device")"
            elif [ ${value2} -eq 0 ]; then
                echo "${search_value} not found."
            elif [ ${value2} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: there are multiple values"
                echo "$(${swift_ring_builder} ${swift_container_builder} search ${search_value} |grep -iv "Device")"
            fi
        elif [[ ${ring_builder_name} == object ]]; then
            local value3=$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep ${host} |grep ${port} |grep ${device_name} |wc -l)
            if [ ${value3} -eq 1 ]; then
                echo "$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep -iv "Device")"
            elif [ ${value3} -eq 0 ]; then
                echo "${search_value} not found."
            elif [ ${value3} -gt 1 ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` WARNING: there are multiple values"
                echo "$(${swift_ring_builder} ${swift_object_builder} search ${search_value} |grep -iv "Device")"
            fi
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: switch to ${swift_ring_path} path failed." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended ring device list check." >> ${log_dir}
}

input_value=$1
if [ -f ${device_config_path} ]; then
    while read ring_device
        do
        check_files
        if [ ! -z `echo ${ring_device} |sed '/^#/d' |sed '/^$/d'` ]; then
            # 从设备列表配置文件中读取信息
            # 设备的操作类型,可选项为 add improve reduce
            action_type=`echo $ring_device |awk -F '|' '{print $1}'`
            # ring环的类型,可选项为 account container object
            ring_builder_name=`echo $ring_device |awk -F '|' '{print $2}'`
            # region值,必须为大于0的正整数
            region_num=`echo $ring_device |awk -F '|' '{print $3}'`
            # zone值,必须为大于0的正整数
            zone_num=`echo $ring_device |awk -F '|' '{print $4}'`
            # 设备的IP地址
            host=`echo $ring_device |awk -F '|' '{print $5}'`
            # ring环对应的服务端口,一般为 6000 6001 6002
            port=`echo $ring_device |awk -F '|' '{print $6}'`
            # 需要操作的挂载设备名称
            device_name=`echo $ring_device |awk -F '|' '{print $7}'`
            # 设置设备的权重值,必须为大于0的正整数,当设置为0时被标记为remove设备
            weight_num=`echo $ring_device |awk -F '|' '{print $8}'`
            # 权重的递增值,必须为大于0的正整数,建议尽量小
            increment_value=`echo $ring_device |awk -F '|' '{print $9}'`
            echo " all value is: ${action_type} r${region_num}z${zone_num}-${host}:${port}/${device_name} ${weight_num}" >> ${log_dir}
            # 检查参数是否符合标准
            check_parameter
            # 组合search value
            search_value="r${region_num}z${zone_num}-${host}:${port}/${device_name}"
            # 检查search value在ring环中的存在情况
            check_search_value
            case ${input_value} in
                start)
                    case ${action_type} in
                        add)
                            # 新增设备的方法
                            ring_add_new_device
                            ;;
                        improve)
                            # 提高当前设备的权重的方法
                            ring_improve_device_weight
                            ;;
                        reduce)
                            # 减少当前设备的权重的方法
                            ring_reduce_device_weight
                            ;;
                        *)
                            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: parameter value is ${action_type} , unable to match the parameters." >> ${log_dir}
                            ;;
                    esac
                    ;;
                check)
                    # 检查设备列表在ring环中的存在情况
                    ring_check_device_list
                    ;;
                *)
                    echo -e $"\nUsage: $0 {start|check}\n"
                    ;;
            esac
        fi
    done < ${device_config_path}
else
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${device_config_path} file not found." >> ${log_dir}
    exit 1
fi
echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended Swift Ring Modify scripts." >> ${log_dir}
