#!/bin/bash

set -Eeuo pipefail

basepath=$(cd `dirname $0`;pwd)
readonly VM_FORMAT_FILE="vm_info_format.txt"
readonly HYPERVISOR_FILE="env_available_host_list.txt"
readonly VOL_TYPE_FILE="env_cinder_volume_type.txt"
readonly IMAGES_FILE="env_image_list.txt"
readonly DATA_SEPARATOR="+"
readonly MAX_PARALLEL=2

log() {
  local lvl="$1" msg="$2"
  printf "%s [%4s] %s\n" "$(date +'%F %T')" "$lvl" "$msg" >&2
  [[ "$lvl" == "ERROR" ]] && exit 1
  return 0
}

trap 'log ERROR "Script aborted in $FUNCNAME at line $LINENO"' ERR

require_cmd() { command -v "$1" &>/dev/null || log ERROR "缺少命令: $1";}
init_deps() { for cmd in openstack nova awk grep sed tee; do require_cmd "$cmd"; done; }

check_volumes(){
    local retries=$1 count=0 vol_ids=("${@:2}")
    for ((i=0; i<retries; i++)); do
        count=0
        for vid in "${vol_ids[@]}"; do
            [[ -z "$vid" || "$vid" == "None" ]] && log ERROR "无效的卷ID"
            local st; st=$(openstack volume show -f value --column status "$vid")
            case "$st" in
                available) count=$((count+1)) ;;
                error*) log ERROR "卷状态显示error, ID: $vid" ;;
            esac
        done
        [[ $count -eq ${#vol_ids[@]} ]] && { echo ok; return 0; }
        sleep 30
    done
    echo "None"
    return 0
}

export_volume_types(){
    > "$1"
    log INFO "正在导出卷类型列表"
    openstack volume type list -f value --column Name | grep -Ev '^(#|$)' > "$1" || echo "None" > "$1"
}

export_hypervisors(){
    > "$1"
    log INFO "正在导出可用的宿主机列表"
    openstack compute service list -f value --service nova-compute \
        | awk '$5 == "enabled" && $6 == "up" {print $4":"$3}' | grep -Ev '^(#|$)' > "$1" || echo "None" > "$1"
}

export_images(){
    > "$1"
    log INFO "正在导出镜像列表"
    openstack image list -f value --column Name | grep -Ev '^(#|$)' > "$1" || echo "None" > "$1"
}

create_boot_volume(){
    local name=$1 size=$2 image=$3 type=$4
    [[ -z "$name" || -z "$size" || -z "$image" || -z "$type" ]] && log ERROR "缺少卷创建参数"
    local vol_name="${name}-sysvol"
    log INFO "创建启动卷: $vol_name"
    local opts=(--size "$size" --image "$(openstack image show -f value --column id "$image")")
    [[ "$type" != "None" ]] && opts+=(--type "$type")
    local id; id=$(openstack volume create -f value --column id "${opts[@]}" "$vol_name")
    log INFO "启动卷已创建, ID: $id"
    echo "$id"
    return 0
}

create_data_vols(){
    local name=$1 size_list=$2 type=$3
    [[ -z "$name" || -z "$size_list" || -z "$type" ]] && log ERROR "缺少卷创建参数"
    IFS="$DATA_SEPARATOR" read -r -a sizes <<<"$size_list"
    for s in "${sizes[@]}"; do
        [[ $s -le 0 ]] && continue
        local vol_name="${name}-datavol-${s}"
        log INFO "创建数据卷: $vol_name"
        local opts=(--size "$s")
        [[ "$type" != "None" ]] && opts+=(--type "$type")
        local id; id=$(openstack volume create -f value --column id "${opts[@]}" "$vol_name")
        log INFO "数据卷已创建, ID: $id"
        echo "$id"
    done
    return 0
}

boot_instance(){
    local name=$1 ip=$2 flavor=$3 net=$4 zone=$5; shift 5
    local vol_ids=("$@") bdevs=() n=0
    [[ -z "$name" || -z "$ip" || -z "$flavor" || -z "$net" || -z "$zone" ]] && log ERROR "缺少启动参数"
    for vid in "${vol_ids[@]}"; do
        bdevs+=(--block-device source=volume,id=$vid,dest=volume,shutdown=preserve,bootindex=$n)
        n=$((n+1))
    done
    log INFO "启动虚拟机: $name"
    log INFO "虚拟机启动指令: $(echo "nova boot --flavor $flavor ${bdevs[@]} --nic net-id=$net,v4-fixed-ip=$ip --availability-zone $zone $name")"
    if [ $(openstack server list --ip "${ip}$" -f value 2>/dev/null | wc -l) -ne 0 ]; then
        log INFO "虚拟机IP已使用, 忽略启动"
        return 0
    fi
    nova boot --flavor "$flavor" "${bdevs[@]}" \
        --nic net-id="$net",v4-fixed-ip="$ip" \
        --availability-zone "$zone" "$name"
    return 0
}

process_vm_line(){
    local line=$1
    local vol_ids=()
    IFS=',' read -r image cpu_mem sys data name vlan ip zone voltype <<<"$line"
    vol_ids+=( $(create_boot_volume "$name" "$sys" "$image" "${voltype:-None}") )
    vol_ids+=( $(create_data_vols "$name" "$data" "${voltype:-None}") )
    [[ "$(check_volumes 30 "${vol_ids[@]}")" == "ok" ]] && \
        boot_instance "$name" "$ip" "$cpu_mem" "$(openstack network list -f csv --column ID --column Name |grep -w "${vlan}" |awk -F'\"' '{print $2}')" "$zone" "${vol_ids[@]}"
    return 0
}

main_vm_task(){
    local infile=$1
    log INFO "开始并发创建虚拟机流程"

    local fifo_file="/tmp/$$.vm_fifo"
    mkfifo "$fifo_file"
    exec 9<>"$fifo_file"
    rm -f "$fifo_file"
    for ((i=0;i<MAX_PARALLEL;i++)); do echo >&9; done

    while IFS= read -r line; do
        [[ -z $line || ${line:0:1} == '#' ]] && continue
        read -t 1000 -u9
        {
            process_vm_line "$line"
            echo >&9
        } &
    done < "$infile"

    wait
    exec 9>&-
    log INFO "所有虚拟机创建流程已执行完成"
    return 0
}

get_item_by_ip() {
    local ip="$1" file="$2"
    if [ ! -r "$file" ]; then
        log WARN "无法访问文件: $file"
        echo -n "None"
        return 0
    fi
    local valid_items=$(awk '!/^#|^$/ {print $1}' "$file")
    local item_count=$(echo "$valid_items" | wc -l)
    if [ "$item_count" -gt 0 ]; then
        local index=$(( (${ip##*.} % item_count) + 1 ))
        echo -n "$(echo "$valid_items" | sed -n "${index}p")"
    else
        echo -n "None"
    fi
    return 0
}

trim(){
    local str="$1"
    echo "$str" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

main_build_task(){
    local file="$1" zone="None" voltype="None"
    [[ ! -f "$file" ]] && log ERROR "读取虚拟机资产信息失败：$file"
    echo "#镜像名称, 规格名称, 系统盘大小, 数据盘大小, 虚拟机名称, VLAN名称, IP地址, 宿主机, 卷类型" > "$VM_FORMAT_FILE"
    while IFS=',' read -r -a fields ; do
        [[ "${#fields[@]}" -eq 0 || "${fields[0]}" =~ ^(#|机房和平台) ]] && continue
        [[ ${#fields[@]} -lt 14 ]] && continue
        img=$(trim "${fields[6]}")
        cpu=$(trim "${fields[7]}")
        mem=$(trim "${fields[8]}")
        sys=$(trim "${fields[9]}")
        data=$(trim "${fields[10]}")
        name=$(trim "${fields[11]}")
        net=$(trim "${fields[12]}")
        vmip=$(trim "${fields[13]}")
        [[ -z "$img" || -z "$cpu" || -z "$mem" || -z "$sys" || -z "$data" || -z "$name" || -z "$net" || -z "$vmip" ]] && continue
        flavor="${cpu}C${mem}G${sys}G"
        if [[ -n "$vmip" ]]; then
            zone=$(get_item_by_ip "$vmip" "$HYPERVISOR_FILE")
            voltype=$(get_item_by_ip "$vmip" "$VOL_TYPE_FILE")
        fi
        if [ "$(grep -c "$img" "$IMAGES_FILE")" -eq 1 ]; then
            img=$(grep "$img" "$IMAGES_FILE")
        else
            log WARN "镜像: $img 不存在, 已忽略"
        fi
        echo "$img,$flavor,$sys,$data,$name,$net,$vmip,$zone,$voltype" | tee -a "$VM_FORMAT_FILE"
    done < "$file"
    log INFO "---- 【重要】请核查配置文件: ${VM_FORMAT_FILE}, 并修正错误 ----"
    return 0
}

main_review_task(){
    local file="$1"
    [[ ! -f "$file" ]] && log ERROR "读取配置文件失败：$file"
    local cluster_images=($(openstack image list -f value -c Name))
    local cluster_flavors=($(openstack flavor list -f value -c Name))
    local cluster_vlans=($(openstack network list -f csv | awk -F'\"' '{print $4}'))
    local cluster_voltypes=($(openstack volume type list -f value -c Name))
    [[ "${#cluster_voltypes[@]}" -eq 0 ]] && cluster_voltypes[0]="None"
    while IFS=',' read -r img flavor sys data name net vmip zone voltype; do
        [[ -z "$img" || -z "$flavor" || -z "$sys" || -z "$data" || -z "$name" || -z "$net" || -z "$vmip" ]] && continue
        [[ "$img" =~ ^(#|$) ]] && continue
        if ! [[ " ${cluster_images[@]} " =~ " ${img} " ]]; then
            log WARN "镜像不存在: ${img} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_flavors[@]} " =~ " ${flavor} " ]]; then
            log WARN "规格不存在: ${flavor} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_vlans[@]} " =~ " ${net} " ]]; then
            log WARN "网络不存在: ${net} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_voltypes[@]} " =~ " ${voltype} " ]]; then
            log WARN "卷类型不存在: ${voltype} (IP: $vmip)"
        fi
        IFS="$DATA_SEPARATOR" read -r -a sizes <<<"$data"
        #local arr=(${data//${DATA_SEPARATOR}/ })
        for size in "${sizes[@]}"; do
            if ! [[ "$size" =~ ^[0-9]+$ ]]; then
                log WARN "数据盘格式检测异常: $size (IP: $vmip), 间隔符号为: ${DATA_SEPARATOR}"
            fi
        done
        log INFO "IP: ${vmip}, 5项检查流程执行完毕"
    done < "$file"
    return 0
}

main(){
    init_deps
    case "$1" in
        init)
            export_hypervisors "$HYPERVISOR_FILE"
            export_volume_types "$VOL_TYPE_FILE"
            export_images "$IMAGES_FILE"
            log INFO "【重要】请人工核实生成的系统环境信息文件【重要】"
            ;;
        build)
            main_build_task "$2"
            ;;
        review)
            main_review_task "$VM_FORMAT_FILE"
            ;;
        run)
            main_vm_task "$VM_FORMAT_FILE"
            ;;
        *)
            log ERROR "Usage: $0 {init|build <src>|review|run}"
            ;;
    esac
}

main "$@"
