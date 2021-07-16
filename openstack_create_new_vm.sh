#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"

global_vm_format_file="vm_info_formart.txt"
global_hyper_list_file="env_available_host_list.txt"
global_vol_type_file="env_cinder_volume_type.txt"
global_images_file="env_image_list.txt"
#global_flavor_file="env_flavor_list.txt"
global_data_separator="+"
global_volumeids=()

logger(){
    local lv="$1"
    local msg="$2"
    case "${lv}" in
        INFO)
            printf "%-8s, %-22s, %-s\n" "[${lv}]" "$(date +"%D %X")" "${msg}" 1>&2
            ;;
        WARN)
            printf "%-8s, %-22s, %-s\n" "[${lv}]" "$(date +"%D %X")" "${msg}" 1>&2
            ;;
        ERROR)
            printf "%-8s, %-22s, %-s\n" "[${lv}]" "$(date +"%D %X")" "${msg}" 1>&2
            exit 1
            ;;
        *)
            printf "%-8s, %-22s, %-s\n" "[ERROR]" "$(date +"%D %X")" "错误的日志打印级别" 1>&2
            exit 1
            ;;
    esac
}

ckVolumeStatus(){
    local n="$1"
    local res="None"
    for ((i=0;i<${n};i++));do
        local stat="0"
        for ((t=0;t<${#global_volumeids[@]};t++));do
            if [ x"${global_volumeids[$t]}" != x"" -a x"${global_volumeids[$t]}" != x"None" ]; then
                local vol_stat="$(openstack volume show -f shell "${global_volumeids[$t]}" |egrep "^status=" |sed -e "s/^status=\"//g" -e "s/\"//g")"
                if [ x"${vol_stat}" == x"available" ]; then
                    stat=$(( ${stat} + 1 ))
                elif [[ "${vol_stat}" =~ ^error.*$ ]]; then
                    logger "ERROR" "创建卷失败, 请检查卷状态: ${global_volumeids[$t]}"
                fi
            else
                logger "ERROR" "读取卷ID为空或者None, 错误的值"
            fi
        done
        if [ x"${stat}" == x"${#global_volumeids[@]}" ] && [ "${stat}" -gt 0 ]; then
            res="ok"
            break
        fi
        sleep 30
    done
    echo -n "${res:-None}"
}

outCinderVolType(){
    local self="$1"
    if (touch ${self} &>/dev/null); then
        cat /dev/null > ${self}
        logger "INFO" "开始读取卷类型列表"
        local n="$(openstack volume type list -f value |awk '{print $2}' |egrep -v "^#|^$")"
        if [ x"${n}" != x"" ]; then
            echo "${n}" > ${self}
        else
            echo "None" > ${self}
        fi
    else
        logger "ERROR" "创建卷类型列表文件失败，请检查当前目录是否有写入权限"
    fi
}

outHypervisorStats(){
    local self="$1"
    local hyper_stats="$(openstack hypervisor list -f value |awk '{print $2}')"
    local hyper_hostlist="$(openstack host list -f value |egrep -w "compute")"
    if (touch ${self} &>/dev/null); then
        cat /dev/null > ${self}
        if [ x"${hyper_stats}" != x"" -a x"${hyper_hostlist}" != x"" ]; then
            logger "INFO" "开始读取可用宿主机列表"
            echo "${hyper_stats}" |while read host;do
                local n="$(echo "${hyper_hostlist}" |egrep -w "${host}")"
                if [ x"${n}" != x"" ]; then
                    echo "${n}" |awk '{print $3":"$1}' >> ${self}
                fi
                unset n
            done
        else
            logger "ERROR" "读取宿主机列表为空，请检查是否正确加载环境变量"
        fi
    else
        logger "ERROR" "创建宿主机列表文件失败，请检查当前目录是否有写入权限"
    fi
}

outFlavorList(){
    local self="$1"
    if (touch ${self} &>/dev/null); then
        cat /dev/null > ${self}
        logger "INFO" "开始读取虚拟机规格列表"
        openstack flavor list -f value |awk '{print $2}' |egrep -v "^#|^$" > ${self}
    else
        logger "ERROR" "创建虚拟机规格列表文件失败，请检查当前目录是否有写入权限"
    fi
}

outImageList(){
    local self="$1"
    if (touch ${self} &>/dev/null); then
        cat /dev/null > ${self}
        logger "INFO" "开始读取虚拟机镜像列表"
        openstack image list -f value |awk '{print $2}' |egrep -v "^#|^$" > ${self}
    else
        logger "ERROR" "创建虚拟机镜像列表文件失败，请检查当前目录是否有写入权限"
    fi
}

initStartEnv(){
    logger "INFO" "读取和初始化系统环境必要信息"
    outHypervisorStats "${global_hyper_list_file}"
    outCinderVolType "${global_vol_type_file}"
    outImageList "${global_images_file}"
    #outFlavorList "{global_flavor_file}"
    logger "INFO" "【重要】请人工核实生成的系统环境信息, 保留需要用到的行, 去除不满足条件的行, 这些配置文件将用于创建虚拟机的基础信息, 文件保存在当前目录下以env_开头的txt文件【重要】"
}

initBlockDevices(){
    local self=($@)
    local blk_devs_cmd=()
    for ((i=0;i<${#self[@]};i++));do
        blk_devs_cmd[${#blk_devs_cmd[@]}]="--block-device source=volume,id=${self[$i]},dest=volume,shutdown=preserve,bootindex=${i}"
    done
    if [ "${#blk_devs_cmd[@]}" -gt 0 ]; then
        logger "INFO" "组装块设备启动顺序为: $(echo "${blk_devs_cmd[@]}")"
        echo -n "${blk_devs_cmd[@]}"
    else
        logger "ERROR" "组装块设备启动顺序失败, 组装列表返回空值"
        echo -n "None"
    fi
}

initHypervZone(){
    local vm_ip="$1"
    local hyperhosts="$2"
    if [ -r "${hyperhosts}" ]; then
        local n="$(egrep -v "^#|^$" ${hyperhosts} |wc -l)"
        if [ ${n} -gt 0 ]; then
            local tn="$(expr $(echo ${vm_ip##*.}) % ${n} + 1 )"
            echo -n "$(egrep -v "^#|^$" ${hyperhosts} |sed -n "${tn}p" |awk '{print $1}')"
        else
            logger "ERROR" "读取宿主机可用列表文件为空，请正确配置宿主机可用列表文件: ${hyperhosts}"
            echo -n "None"
        fi
    else
        logger "ERROR" "无法访问宿主机可用列表文件，请正确配置宿主机可用列表文件: ${hyperhosts}"
    fi
}

initCinderVolType(){
    local vm_ip="$1"
    local voltype_file="$2"
    if [ -r "${voltype_file}" ]; then
        local n="$(egrep -v "^#|^$" ${voltype_file} |wc -l)"
        if [ ${n} -gt 0 ]; then
            local tn="$(expr $(echo ${vm_ip##*.}) % ${n} + 1 )"
            echo -n "$(egrep -v "^#|^$" ${voltype_file} |sed -n "${tn}p" |awk '{print $1}')"
        else
            echo -n "None"
        fi
    else
        logger "ERROR" "无法访问卷类型列表文件，请正确配置文件: ${voltype_file}"
    fi
}

crBootVolume(){
    local boot_volume_name="$1"
    local vol_size="$2"
    local image_name="$3"
    local vol_type="$4"
    if [ x"${boot_volume_name}" != x"" -a x"${vol_size}" != x"" -a x"${image_name}" != x"" -a x"${vol_type}" != x"" ]; then
        local image_id="$(openstack image list -f value |grep -w "${image_name}" |awk '{print $1}' |sed -n '1p')"
        if [ x"${vol_type}" == x"None" ]; then
            if [ $(openstack volume list --name "${boot_volume_name}" -f value 2>/dev/null |wc -l) -eq 0 ]; then
                logger "INFO" "开始创建启动卷: ${boot_volume_name:-None}"
                local msg="$(openstack volume create -f shell --size "${vol_size}" --image "${image_id}" "${boot_volume_name}")"
                local boot_volume_id="$(echo "${msg}" |egrep -w "^id=.*" |awk -F'\"' '{print $2}')"
                logger "INFO" "已执行启动卷创建，卷ID: ${boot_volume_id:-None}"
            else
                logger "ERROR" "创建启动卷失败, 发现重名的卷: ${boot_volume_name}"
            fi
        else
            if [ $(openstack volume list --name "${boot_volume_name}" -f value 2>/dev/null |wc -l) -eq 0 ]; then
                logger "INFO" "开始创建启动卷: ${boot_volume_name:-None}"
                local msg="$(openstack volume create -f shell --size "${vol_size}" --type "${vol_type}" --image "${image_id}" "${boot_volume_name}")"
                local boot_volume_id="$(echo "${msg}" |egrep -w "^id=.*" |awk -F'\"' '{print $2}')"
                logger "INFO" "已执行启动卷创建，卷ID: ${boot_volume_id:-None}"
            else
                logger "ERROR" "创建启动卷失败, 发现重名的卷: ${boot_volume_name}"
            fi
        fi
    else
        logger "ERROR" "创建启动卷失败, 入参变量不能为空"
    fi
    echo -n "${boot_volume_id:-None}"
}

crDataVolume(){
    local data_volume_name="$1"
    local vol_size="$2"
    local vol_type="$3"
    if [ x"${data_volume_name}" != x"" -a x"${vol_size}" != x"" -a x"${vol_type}" != x"" ]; then
        if [ x"${vol_type}" == x"None" ]; then
            #if [ $(openstack volume list --name "${data_volume_name}" -f value 2>/dev/null |wc -l) -eq 0 ]; then
                logger "INFO" "开始创建数据卷: ${data_volume_name:-None}"
                local msg="$(openstack volume create -f shell --size "${vol_size}" "${data_volume_name}")"
                local data_volume_id="$(echo "${msg}" |egrep -w "^id=.*" |awk -F'\"' '{print $2}')"
                logger "INFO" "已执行数据卷创建，卷ID: ${data_volume_id:-None}"
            #else
            #    logger "ERROR" "创建数据卷失败, 发现重名的卷: ${data_volume_name}"
            #fi
        else
            #if [ $(openstack volume list --name "${data_volume_name}" -f value 2>/dev/null |wc -l) -eq 0 ]; then
                logger "INFO" "开始创建数据卷: ${data_volume_name:-None}"
                local msg="$(openstack volume create -f shell --size "${vol_size}" --type "${vol_type}" "${data_volume_name}")"
                local data_volume_id="$(echo "${msg}" |egrep -w "^id=.*" |awk -F'\"' '{print $2}')"
                logger "INFO" "已执行数据卷创建，卷ID: ${data_volume_id:-None}"
            #else
            #    logger "ERROR" "创建启动卷失败, 发现重名的卷: ${data_volume_name}"
            #fi
        fi
    else
        logger "ERROR" "创建数据卷失败, 入参变量不能为空"
    fi
    echo -n "${data_volume_id:-None}"
}

crBootInstance(){
    local vmname="$1"
    local vm_ip="$2"
    local flavor_name="$3"
    local net_id="$4"
    local host_zone="$5"
    local blk_devs_cmd="$(initBlockDevices "${global_volumeids[@]}")"
    if [ x"${vmname}" != x"" -a x"${vm_ip}" != x"" -a x"${flavor_name}" != x"" -a x"${net_id}" != x"" -a x"${host_zone}" != x"" -a x"${blk_devs_cmd}" != x"" -a x"${vmname}" != x"None" -a x"${vm_ip}" != x"None" -a x"${flavor_name}" != x"None" -a x"${net_id}" != x"None" -a x"${blk_devs_cmd}" != x"None" ]; then
        if [ $(openstack server list --name "${vmname}" --ip "${vm_ip}" -f value 2>/dev/null |wc -l) -eq 0 ]; then
            logger "INFO" "开始启动虚拟机: ${vmname:-None}"
            local msg="$(nova boot --flavor ${flavor_name} ${blk_devs_cmd} --nic net-id=${net_id},v4-fixed-ip=${vm_ip} --availability-zone "${host_zone}" "${vmname}")"
            logger "INFO" "已执行启动虚拟机, 创建信息如下: $(echo -e "\n${msg:-None}\n")"
        else
            logger "ERRO" "启动虚拟机失败, 创建的虚拟机已存在"
        fi
    else
        logger "ERROR" "启动虚拟机失败, 入参变量不能为空"
    fi
}

doVMRootTask(){
    local self="$1"
    if [ -r "${self}" ] && [ x"${self}" != x"" ]; then
        logger "INFO" "开始执行虚拟机创建流程"
        while read line;do
            global_volumeids=()
            if [ x"$(echo "${line}" |egrep -v "^#|^$")" != x"" ]; then
                # make value
                local image_name="$(echo ${line} |awk -F',' '{print $1}')"
                local flavor_format="$(echo ${line} |awk -F',' '{print $2}')"
                local v_sys_size="$(echo ${line} |awk -F',' '{print $3}')"
                local v_data_size="$(echo ${line} |awk -F',' '{print $4}')"
                local v_name="$(echo ${line} |awk -F',' '{print $5}')"
                local vlan_name="$(echo ${line} |awk -F',' '{print $6}')"
                local vm_ip="$(echo ${line} |awk -F',' '{print $7}')"
                local host_zone="$(echo ${line} |awk -F',' '{print $8}')"
                local vol_type="$(echo ${line} |awk -F',' '{print $9}')"
                # create boot volume
                logger "INFO" "虚拟机${v_name}开始创建启动卷"
                local vm_volume1="$(crBootVolume "${v_name}-sysvol" "${v_sys_size}" "${image_name}" "${vol_type:-None}")"
                global_volumeids[${#global_volumeids[@]}]="${vm_volume1:-None}"
                # create data volume
                logger "INFO" "虚拟机${v_name}开始创建数据卷"
                local arr=(${v_data_size//${global_data_separator}/ })
                for ((i=0;i<${#arr[@]};i++));do
                    if [ "${arr[$i]}" -gt 0 ]; then
                        local vm_volume2="$(crDataVolume "${v_name}-datavol" "${arr[$i]}" "${vol_type:-None}")"
                        global_volumeids[${#global_volumeids[@]}]="${vm_volume2:-None}"
                    fi
                done
                # check volume status
                logger "INFO" "虚拟机${v_name}等待所有卷创建完成"
                local s="$(ckVolumeStatus "30")"
                if [ x"${s}" == x"ok" ]; then
                    local net_id="$(openstack network list -f csv |egrep "${vlan_name}" |awk -F'\"' '{print $2}')"
                    crBootInstance "${v_name}" "${vm_ip}" "${flavor_format}" "${net_id}" "${host_zone}"
                else
                    logger "ERROR" "创建卷似乎失败了, 请检查卷的状态"
                fi
            fi
        done < ${self}
    else
        logger "ERROR" "读取虚拟机资产信息失败，没有找到${self}文件"
    fi
}

doVMInfoFormat(){
    local self="$1"
    if [ -r "${self}" ] && [ x"${self}" != x"" ]; then
        if (touch ${global_vm_format_file} &>/dev/null); then
            logger "INFO" "开始对输入的文件进行基本信息解析"
            cat /dev/null > ${global_vm_format_file}
            echo "#镜像名称, 规格名称, 系统盘大小, 数据盘大小, 虚拟机名称, VLAN名称, IP地址, 宿主机, 卷类型" > ${global_vm_format_file}
            while read line;do
                if [ x"${line}" != x"" ]; then
                    local image_name="$(echo ${line} |awk -F',' '{print $7}' |awk '{print $1}')"
                    if [ "$(egrep -ic "${image_name}" ${global_images_file})" -eq 1 ]; then
                        image_name="$(egrep "${image_name}" ${global_images_file})"
                    else
                        logger "WARN" "匹配到零个或多个相似镜像名, 当前值: ${image_name}, 请检查${global_images_file}"
                    fi
                    local v_cpu="$(echo ${line} |awk -F',' '{print $8}')"
                    local v_mem="$(echo ${line} |awk -F',' '{print $9}')"
                    local v_sys_size="$(echo ${line} |awk -F',' '{print $10}')"
                    local flavor_format="${v_cpu}C${v_mem}G${v_sys_size}G"
                    local v_data_size="$(echo ${line} |awk -F',' '{print $11}')"
                    local v_name="$(echo ${line} |awk -F',' '{print $12}')"
                    local vlan_name="$(echo ${line} |awk -F',' '{print $13}')"
                    local vm_ip="$(echo ${line} |awk -F',' '{print $14}')"
                    if [ x"${vm_ip}" != x"" ]; then
                        local host_zone="$(initHypervZone "${vm_ip}" "${global_hyper_list_file}")"
                        local vol_type="$(initCinderVolType "${vm_ip}" "${global_vol_type_file}")" 
                    else
                        local host_zone="None"
                        local vol_type="None"
                        logger "WARN" "读取IP信息为空值, 请检查输入文件格式是否正确"
                    fi
                    echo "${image_name},${flavor_format},${v_sys_size},${v_data_size},${v_name},${vlan_name},${vm_ip},${host_zone},${vol_type}" >> ${global_vm_format_file}
                fi
            done < ${self}
            cat ${global_vm_format_file} |awk -F',' '{printf "|%-40s|%-12s|%-8s|%-8s|%-32s|%-20s|%-20s|%-20s|%-20s|\n",$1,$2,$3,$4,$5,$6,$7,$8,$9}'
            logger "INFO" "【重要】请反复核查虚拟机基本信息, 手动修改文件${global_vm_format_file}, 更正错误的信息【重要】"
        else
            logger "ERROR" "创建虚拟机信息文件失败，请检查当前目录是否有写入权限"
        fi
    else
        logger "ERROR" "读取虚拟机资产信息失败，没有找到${self}文件"
    fi
}

doReviewInfo(){
    local self="$1"
    if [ -r "${self}" ]; then
        logger "INFO" "开始对输入的文件进行基本信息检查"
        # get cluster status
        local cluster_image_list="$(openstack image list -f value |awk '{print $2}')"
        local cluster_flavor_list="$(openstack flavor list -f value |awk '{print $2}')"
        local cluster_vlans="$(openstack network list -f csv |awk -F'\"' '{print $4}')"
        local cluster_voltype_list="$(openstack volume type list -f value |awk '{print $2}')"
        while read line;do
            if [ "$(echo "${line}" |egrep -vc "^#|^$")" -eq 1 ]; then
                local image_name="$(echo ${line} |awk -F',' '{print $1}')"
                local flavor_format="$(echo ${line} |awk -F',' '{print $2}')"
                local v_sys_size="$(echo ${line} |awk -F',' '{print $3}')"
                local v_data_size="$(echo ${line} |awk -F',' '{print $4}')"
                local v_name="$(echo ${line} |awk -F',' '{print $5}')"
                local vlan_name="$(echo ${line} |awk -F',' '{print $6}')"
                local vm_ip="$(echo ${line} |awk -F',' '{print $7}')"
                local host_zone="$(echo ${line} |awk -F',' '{print $8}')"
                local vol_type="$(echo ${line} |awk -F',' '{print $9}')"
                if [ "$(echo "${cluster_image_list}" |egrep -w "^${image_name}$" |wc -l)" -eq 1 ]; then
                    if [ "$(echo "${cluster_flavor_list}" |egrep -w "^${flavor_format}$" |wc -l)" -eq 1 ]; then
                        if [ "$(echo "${cluster_vlans}" |egrep -w "^${vlan_name}$" |wc -l)" -eq 1 ]; then
                            if [ "$(echo "${cluster_voltype_list}" |egrep -w "^${vol_type}$" |wc -l)" -eq 1 ]; then
                                local arr=(${v_data_size//${global_data_separator}/ })
                                local var="0"
                                for ((i=0;i<${#arr[@]};i++));do
                                    if [ "$(echo "${arr[i]}" |egrep -c "^[[:digit:]]+$")" -eq 1 ]; then
                                        var=$(( ${var} + 1 ))
                                    else
                                        logger "ERROR" "IP: ${vm_ip}, 虚拟机数据盘表达格式不合格, 请以 ${global_data_separator} 符号间隔数据盘大小"
                                    fi
                                done
                                if [ x"${var}" == x"${#arr[@]}" ]; then
                                    logger "INFO" "IP: ${vm_ip}, 主机5项信息检查通过"
                                else
                                    logger "ERROR" "IP: ${vm_ip}, 虚拟机数据盘表达格式不合格, 请以 ${global_data_separator} 符号间隔数据盘大小"
                                fi
                            else
                                logger "ERROR" "检查到零个或多个相同卷类型名${vol_type}, 请更正, IP: ${vm_ip}"
                            fi
                        else
                            logger "ERROR" "检查到零个或多个相同网络名${vlan_name}, 请更正, IP: ${vm_ip}"
                        fi
                    else
                        logger "ERROR" "检查到零个或多个相同规格名${flavor_format}, 请更正, IP: ${vm_ip}"
                    fi
                else
                    logger "ERROR" "检查到零个或多个相同镜像名${image_name}, 请更正, IP: ${vm_ip}"
                fi
            fi
        done < ${self}
    else
        logger "ERROR" "读取虚拟机信息失败，没有找到${self}文件"
    fi
}

main(){
    local type="$1"
    local in_file="$2"
    case "${1}" in
        run)
            doVMRootTask "${global_vm_format_file}"
            ;;
        review)
            doReviewInfo "${global_vm_format_file}"
            ;;
        build)
            doVMInfoFormat "${in_file}"
            ;;
        init)
            initStartEnv
            ;;
        *)
            logger "ERROR" "输入参数错误, 依次执行 init -> build -> review -> run"
            ;;
    esac
}

main "$@"
