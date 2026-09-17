#!/bin/bash

set -Eeuo pipefail

basepath=$(cd `dirname $0`;pwd)
readonly VM_FORMAT_FILE="vm_info_format.txt"
readonly HYPERVISOR_FILE="env_available_host_list.txt"
readonly VOL_TYPE_FILE="env_cinder_volume_type.txt"
readonly IMAGES_FILE="env_image_list.txt"
readonly DATA_SEPARATOR="+"
readonly MAX_PARALLEL=2

CFGDRIVE=0

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
        # 空数组守卫: bash 4.2 + set -u 下空数组展开会报 unbound variable
        for vid in ${vol_ids[@]+"${vol_ids[@]}"}; do
            [[ -z "$vid" || "$vid" == "None" ]] && log ERROR "无效的卷ID"
            # 两段式命令替换: 显式区分"查询失败"与"卷未就绪"
            local st rc=0
            st=$(openstack volume show -f value --column status "$vid" 2>/dev/null) || rc=$?
            if [[ $rc -ne 0 ]]; then
                log WARN "卷状态查询失败(exit=$rc), 稍后重试: $vid"
                continue
            fi
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
    [[ -z "$name" || -z "$type" ]] && log ERROR "缺少卷创建参数"
    # 空数据盘字段视为"无数据盘", 直接返回而非报错
    [[ -z "$size_list" ]] && return 0
    IFS="$DATA_SEPARATOR" read -r -a sizes <<<"$size_list"
    # 空数组守卫: bash 4.2 + set -u 下空数组展开会报 unbound variable
    for s in ${sizes[@]+"${sizes[@]}"}; do
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

ip_in_use(){
    local ip=$1 rc=0 out
    # 两段式命令替换: 显式区分"查询失败"与"确实空闲"。
    # 查询失败时按保守方向判定为"可能已占用"(返回真), 避免误判空闲导致IP冲突。
    out=$(openstack server list --ip "${ip}$" -f value 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        log WARN "IP占用查询失败(exit=$rc), 保守判定为可能已占用: $ip"
        return 0
    fi
    [[ -n "$out" ]]
}

# 将卷ID列表转换为 nova boot 所需的块设备参数, 逐行输出到stdout。
# 不使用数组名传参(bash 4.2 不支持 nameref, 且原实现写入局部副本导致回填失效),
# 由调用方按行读入自己的数组。
build_bdevs(){
    local n=0 vid
    for vid in "$@"; do
        printf '%s\n' "--block-device"
        printf '%s\n' "source=volume,id=${vid},dest=volume,shutdown=preserve,bootindex=${n}"
        n=$((n+1))
    done
}

nova_boot(){
    local out rc id
    log INFO "执行 nova boot: $(echo "nova boot $@")"
    out=$(nova boot "$@" 2>&1) || rc=$?
    if [[ -n "${rc:-}" ]]; then
        log ERROR "nova boot 执行失败 (exit=$rc)"
    fi
    # 提取首个合法 UUID, 不依赖表头文本大小写或列位置。
    # 末尾 || true: 避免 grep 无匹配时因 pipefail 触发 ERR trap 而绕过下方报错。
    id=$(grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' <<<"$out" | head -n1 || true)
    if [[ -z "$id" ]]; then
        log ERROR "nova boot 输出未解析到实例 ID, 原始输出: $out"
    fi
    printf '%s\n' "$id"
}

wait_server_active(){
    local id=$1
    local interval="${VM_WAIT_INTERVAL:-15}" timeout="${VM_WAIT_TIMEOUT:-600}"
    local waited=0 st slow_flag=0 abn_flag=0 first=1
    while (( waited < timeout )); do
        # 两段式命令替换: 单次查询失败不终止, 记录后继续重试
        local rc=0
        st=$(openstack server show -c status -f value "$id" 2>/dev/null) || rc=$?
        if [[ $rc -ne 0 ]]; then
            log WARN "实例状态查询失败(exit=$rc), 稍后重试: $id"
            sleep "$interval"
            waited=$((waited + interval))
            continue
        fi
        [[ "$st" == "ERROR" ]] && log ERROR "实例 $id 状态为 ERROR, 启动失败"
        [[ "$st" == "ACTIVE" ]] && { echo ok; return 0; }
        if (( first == 1 )); then
            log INFO "实例创建中,等待调度, 当前状态: $st"
            first=0
        elif (( slow_flag == 0 && waited >= 120 )); then
            log WARN "启动偏慢, 当前状态: $st"
            slow_flag=1
        elif (( abn_flag == 0 && waited >= 300 )); then
            log WARN "启动异常偏慢, 当前状态: $st"
            abn_flag=1
        fi
        sleep "$interval"
        waited=$((waited + interval))
    done
    log ERROR "等待实例 $id 状态为 ACTIVE 超时, 已超过 ${timeout} 秒"
}

wait_server_shutoff(){
    local id=$1
    local interval="${VM_STOP_INTERVAL:-15}" timeout="${VM_STOP_TIMEOUT:-300}"
    local waited=0 st
    while (( waited < timeout )); do
        # 两段式命令替换: 单次查询失败不终止, 记录后继续重试
        local rc=0
        st=$(openstack server show -c status -f value "$id" 2>/dev/null) || rc=$?
        if [[ $rc -ne 0 ]]; then
            log WARN "实例状态查询失败(exit=$rc), 稍后重试: $id"
            sleep "$interval"
            waited=$((waited + interval))
            continue
        fi
        [[ "$st" == "ERROR" ]] && log ERROR "实例 $id 状态为 ERROR, 关机失败"
        [[ "$st" == "SHUTOFF" ]] && { echo ok; return 0; }
        sleep "$interval"
        waited=$((waited + interval))
    done
    echo "None"
    return 0
}

cleanup_vols(){
    local vols=("$@")
    [[ ${#vols[@]} -eq 0 ]] && return 0
    log WARN "VM流程失败, 清理已创建的卷: ${vols[*]}"
    for vid in "${vols[@]}"; do
        [[ -z "$vid" || "$vid" == "None" ]] && continue
        local att_server
        att_server=$(openstack volume show -f value -c attached_servers "$vid" 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n1 || true)
        if [[ -n "$att_server" ]]; then
            openstack server delete --wait "$att_server" || log WARN "清理卷关联实例失败: $att_server"
        fi
        openstack volume delete "$vid" || log WARN "清理卷失败: $vid"
    done
    return 0
}

boot_instance(){
    local name=$1 ip=$2 flavor=$3 net=$4 zone=$5; shift 5
    local vol_ids=("$@") bdevs=()
    [[ -z "$name" || -z "$ip" || -z "$flavor" || -z "$net" || -z "$zone" ]] && log ERROR "缺少启动参数"
    # 逐行读入块设备参数(bash 4.2 无 mapfile); 空卷集合时 bdevs 保持为空
    local _bd_line
    while IFS= read -r _bd_line; do bdevs+=("$_bd_line"); done \
        < <(build_bdevs ${vol_ids[@]+"${vol_ids[@]}"})
    if ip_in_use "$ip"; then
        log INFO "虚拟机IP已使用, 忽略启动"
        return 0
    fi
    log INFO "启动虚拟机: $name"
    local id
    id=$(nova_boot \
        --flavor "$flavor" \
        --nic "net-id=${net},v4-fixed-ip=${ip}" \
        --availability-zone "$zone" \
        ${bdevs[@]+"${bdevs[@]}"} \
        "$name")
    wait_server_active "$id"
    return 0
}

cfgdrive_two_stage(){
    local name=$1 ip=$2 flavor=$3 net=$4 zone=$5; shift 5
    local vol_ids=("$@") bdevs=()
    [[ -z "$name" || -z "$ip" || -z "$flavor" || -z "$net" || -z "$zone" ]] && log ERROR "缺少启动参数"
    # 逐行读入块设备参数(bash 4.2 无 mapfile); 空卷集合时 bdevs 保持为空
    local _bd_line
    while IFS= read -r _bd_line; do bdevs+=("$_bd_line"); done \
        < <(build_bdevs ${vol_ids[@]+"${vol_ids[@]}"})

    # 第一阶段
    if ip_in_use "$ip"; then
        log INFO "虚拟机IP已使用, 忽略启动"
        return 0
    fi
    log INFO "config-drive 第一阶段 boot: $name"
    local id
    id=$(nova_boot \
        --config-drive true \
        --user-data "$basepath/cloud-init-remove.yaml" \
        --flavor "$flavor" \
        --nic "net-id=${net},v4-fixed-ip=${ip}" \
        --availability-zone "$zone" \
        ${bdevs[@]+"${bdevs[@]}"} \
        "$name")
    wait_server_active "$id"
    log INFO "config-drive 实例已 ACTIVE: $name"

    # 等待 cloud-init power_state 优雅关机
    if [[ "$(wait_server_shutoff "$id")" != "ok" ]]; then
        log WARN "config-drive 优雅关机超时, 执行 server stop 兜底: $name"
        openstack server stop "$id"
        if [[ "$(wait_server_shutoff "$id")" != "ok" ]]; then
            log ERROR "config-drive 实例 stop 后仍未进入 SHUTOFF: $name"
        fi
    fi
    log INFO "config-drive 实例已 SHUTOFF: $name"

    # 删除第一阶段实例
    if ! openstack server delete --wait "$id"; then
        log ERROR "config-drive 删除实例失败: $name"
    fi
    log INFO "config-drive 实例已删除: $name"

    # 卷回收回 available
    [[ "$(check_volumes 30 "${vol_ids[@]}")" != "ok" ]] && \
        log ERROR "config-drive 卷回收失败: $name"

    # 第二阶段: 等待 IP 释放
    local ip_waited=0 ip_interval=10 ip_timeout="${VM_IP_WAIT_TIMEOUT:-300}"
    while (( ip_waited < ip_timeout )); do
        if ! ip_in_use "$ip"; then
            break
        fi
        sleep "$ip_interval"
        ip_waited=$((ip_waited + ip_interval))
    done
    if ip_in_use "$ip"; then
        log ERROR "config-drive 第二阶段前 IP 仍被占用, 等待超时: $ip"
    fi
    log INFO "config-drive 第二阶段 boot: $name"
    id=$(nova_boot \
        --flavor "$flavor" \
        --nic "net-id=${net},v4-fixed-ip=${ip}" \
        --availability-zone "$zone" \
        ${bdevs[@]+"${bdevs[@]}"} \
        "$name")
    local ret
    ret=$(wait_server_active "$id")
    [[ "$ret" != "ok" ]] && log ERROR "config-drive 第二阶段实例未进入 ACTIVE: $name"
    return 0
}

process_vm_line(){
    local line=$1
    local vol_ids=()
    IFS=',' read -r image cpu_mem sys data name vlan ip zone voltype <<<"$line"
    # 空数组守卫: bash 4.2 + set -u 下 vol_ids 可能为空
    trap 'rc=$?; [[ $rc -ne 0 ]] && cleanup_vols ${vol_ids[@]+"${vol_ids[@]}"}; echo >&9' EXIT
    vol_ids+=( $(create_boot_volume "$name" "$sys" "$image" "${voltype:-None}") )
    vol_ids+=( $(create_data_vols "$name" "$data" "${voltype:-None}") )
    # 卷集合为空(启动卷创建失败) => 该VM流程失败; 显式拦截, 避免空数组展开崩溃
    [[ ${#vol_ids[@]} -eq 0 ]] && log ERROR "卷集合为空, 终止当前VM: $name"
    # 按VLAN名查网络: 命令失败或无匹配时明确报错终止该VM, 不静默以空值继续
    local netid rc=0
    netid=$(openstack network list -f csv --column ID --column Name 2>/dev/null \
        | grep -w "${vlan}" | awk -F'\"' '{print $2}' | head -n1) || rc=$?
    if [[ $rc -ne 0 || -z "$netid" ]]; then
        log ERROR "网络查找失败或不存在: VLAN=${vlan}, VM=${name}"
    fi
    local vols_ready
    vols_ready=$(check_volumes 30 ${vol_ids[@]+"${vol_ids[@]}"})
    if [[ "$vols_ready" != "ok" ]]; then
        log ERROR "卷创建后未就绪, 终止当前VM: $name"
    fi
    if [[ "$CFGDRIVE" == "1" ]]; then
        cfgdrive_two_stage "$name" "$ip" "$cpu_mem" "$netid" "$zone" ${vol_ids[@]+"${vol_ids[@]}"}
    else
        boot_instance "$name" "$ip" "$cpu_mem" "$netid" "$zone" ${vol_ids[@]+"${vol_ids[@]}"}
    fi
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

    local -a pids=()
    local failed_count=0 skipped_count=0

    while IFS= read -r line; do
        [[ -z $line || ${line:0:1} == '#' ]] && continue
        read -t "${VM_READ_TIMEOUT:-5400}" -u9 || {
            log WARN "并发读令牌超时, 跳过该次调度"
            skipped_count=$((skipped_count+1))
            continue
        }
        {
            trap 'echo >&9' EXIT
            process_vm_line "$line"
        } &
        pids+=($!)
        sleep 1
    done < "$infile"

    # 空数组守卫: bash 4.2 + set -u 下 "${pids[@]}" 对空数组会报 unbound variable
    for pid in ${pids[@]+"${pids[@]}"}; do
        if wait "$pid"; then
            :
        else
            failed_count=$((failed_count+1))
        fi
    done
    exec 9>&-

    if (( skipped_count > 0 )); then
        log WARN "本轮有 ${skipped_count} 行VM因令牌读取超时被跳过"
    fi
    if (( failed_count > 0 )); then
        log ERROR "本轮共 ${failed_count} 个VM失败"
    fi
    if (( skipped_count > 0 )); then
        exit 1
    fi
    log INFO "所有虚拟机创建流程已执行完成"
    return 0
}

get_item_by_ip() {
    local ip="$1" file="$2"
    local last="${ip##*.}"
    # 候选清单不可读: 告警并降级为不指定
    if [ ! -r "$file" ]; then
        log WARN "无法访问文件: $file"
        echo -n "None"
        return 0
    fi
    # IP 末段非数值: 无法做取模选择, 降级为不指定(避免算术求值 unbound)
    if ! [[ "$last" =~ ^[0-9]+$ ]]; then
        log WARN "IP末段非数值, 无法选择宿主机/卷类型, 降级为不指定: $ip"
        echo -n "None"
        return 0
    fi
    # 两段式命令替换; 过滤注释与空行后按行统计, 避免空内容被 wc -l 记为 1
    local valid_items rc=0
    valid_items=$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$file" 2>/dev/null) || rc=$?
    if [[ $rc -ne 0 ]]; then
        log WARN "读取候选清单失败(exit=$rc), 降级为不指定: $file"
        echo -n "None"
        return 0
    fi
    local item_count=0
    [[ -n "$valid_items" ]] && item_count=$(printf '%s\n' "$valid_items" | wc -l)
    # 候选清单为空: 不误选
    if [ "$item_count" -le 0 ]; then
        log WARN "候选清单为空, 降级为不指定: $file"
        echo -n "None"
        return 0
    fi
    local index=$(( (last % item_count) + 1 ))
    printf '%s' "$(printf '%s\n' "$valid_items" | sed -n "${index}p")"
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
        else
            zone="None"
            voltype="None"
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
        # 空集合守卫: bash 4.2 + set -u 下空数组展开会报 unbound variable
        if ! [[ " ${cluster_images[@]+"${cluster_images[@]}"} " =~ " ${img} " ]]; then
            log WARN "镜像不存在: ${img} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_flavors[@]+"${cluster_flavors[@]}"} " =~ " ${flavor} " ]]; then
            log WARN "规格不存在: ${flavor} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_vlans[@]+"${cluster_vlans[@]}"} " =~ " ${net} " ]]; then
            log WARN "网络不存在: ${net} (IP: $vmip)"
        fi
        if ! [[ " ${cluster_voltypes[@]+"${cluster_voltypes[@]}"} " =~ " ${voltype} " ]]; then
            log WARN "卷类型不存在: ${voltype} (IP: $vmip)"
        fi
        IFS="$DATA_SEPARATOR" read -r -a sizes <<<"$data"
        #local arr=(${data//${DATA_SEPARATOR}/ })
        # 空数组守卫: bash 4.2 + set -u 下空数组展开会报 unbound variable
        for size in ${sizes[@]+"${sizes[@]}"}; do
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
    local args=() a
    local parse_cfgdrive=0
    for a in "$@"; do
        if [[ "$a" == "--cfgdrive" ]]; then
            parse_cfgdrive=1
        else
            args+=("$a")
        fi
    done
    CFGDRIVE=$parse_cfgdrive
    local cmd="${args[0]:-}"
    if [[ "$parse_cfgdrive" == "1" && ( "$cmd" == "init" || "$cmd" == "build" || "$cmd" == "review" ) ]]; then
        log WARN "--cfgdrive 仅对 run 生效, 已忽略"
    fi
    case "$cmd" in
        init)
            export_hypervisors "$HYPERVISOR_FILE"
            export_volume_types "$VOL_TYPE_FILE"
            export_images "$IMAGES_FILE"
            log INFO "【重要】请人工核实生成的系统环境信息文件【重要】"
            ;;
        build)
            main_build_task "${args[1]:-}"
            ;;
        review)
            main_review_task "$VM_FORMAT_FILE"
            ;;
        run)
            main_vm_task "$VM_FORMAT_FILE"
            ;;
        *)
            log ERROR "Usage: $0 [--cfgdrive] {init|build <src>|review|run}"
            ;;
    esac
}

main "$@"
