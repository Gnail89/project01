#!/bin/bash

node_bond0_macs="08:30:ce:06:2b:cc 08:30:ce:06:33:aa"
node_bond0_mode="mode=active-backup,miimon=100"
node_bond0_ip="192.168.1.1"
node_bond0_prefix="24"
node_bond0_netmask="255.255.255.0"
node_bond0_gw="192.168.1.1"

create_rootvg_partition(){
    # 使用xfs文件系统
    os_rootvg="$(lsblk -r |grep -w "/" |awk -F'-' '{print $1}')"
    if [ x"${os_rootvg}" != x"" ]; then
        local parts='
        resize|root|/|50G
        resize|user|/usr|50G
        resize|var|/var|50G
        resize|home|/home|50G
        create|swap|swap|8G
        create|tmp|/tmp|20G
        '
        for line in ${parts};do
            local type="$(echo ${line} |awk -F'|' '{print $1}')"
            local part_name="$(echo ${line} |awk -F'|' '{print $2}')"
            local part_dir="$(echo ${line} |awk -F'|' '{print $3}')"
            local part_size="$(echo ${line} |awk -F'|' '{print $4}')"
            case ${type} in
                create)
                    lvcreate -y -L ${part_size} -n ${part_name} ${os_rootvg}
                    mkfs.xfs -f /dev/${os_rootvg}/${part_name}
                    if [ $(grep "/dev/${os_rootvg}/${part_name}" /etc/fstab |wc -l) -eq 0 ]; then
                        [ ! -d ${part_dir} ] && mkdir -p ${part_dir}
                        echo "/dev/${os_rootvg}/${part_name}  ${part_dir}  xfs  defaults  0 0" >> /etc/fstab
                    fi
                    ;;
                resize)
                    lvextend -L ${part_size} -n /dev/${os_rootvg}/${part_name}
                    xfs_growfs /dev/${os_rootvg}/${part_name}
                    # xfs_growfs ${part_dir}
                    ;;
                *)
                    echo "type error"
                    ;;
            esac
        done
    else
        echo "get rootvg info failed"
    fi
}

create_users(){
    local users='
    user:pass
    '

    for line in ${users};do
        local name="$(echo ${line} |awk -F':' '{print $1}')"
        useradd -m ${name}
        echo "${$line}" |chpasswd
    done
}

resize_os_partition(){
    # 获取安装系统的磁盘
    os_disk="$(lsblk -r |grep -w "/boot" |cut -c1-3)"

    # 获取/根文件系统所在的vg
    os_rootvg="$(lsblk -r |grep -w "/" |awk -F'-' '{print $1}')"

    # 获取/根文件系统所在的盘符路径
    if [ x"${os_disk}" != x"" ] && [ x"${os_rootvg}" != x"" ]; then
        os_rootvg_path="$(pvs |grep -w "${os_rootvg}" |egrep -o "/dev/${os_disk}[[:digit:]]+")"
    else
        os_rootvg_path=""
    fi
    
    # 获取/根文件系统所在分区号
    if [ x"${os_rootvg_path}" != x"" ]; then
        os_rootvg_path_num="$(lsblk -r |grep -w "$(echo ${os_rootvg_path} |awk -F'/' '{print $NF}')" |awk '{print $2}' |awk -F':' '{print $NF}')"
    else
        os_rootvg_path_num=""
    fi
    
    # resize系统盘，扩容至100%
    if [ x"${os_disk}" != x"" ] && [ x"${os_rootvg_path}" != x"" ] && [ x"${os_rootvg_path_num}" != x"" ]; then
        parted /dev/${os_disk} resizepart ${os_rootvg_path_num} 100%
        pvresize ${os_rootvg_path}
    else
        echo "resize root disk failed"
    fi
}

net_setup_nmcli(){
    if [ x"$(systemctl is-enabled NetworkManager)" != x"enabled" ]; then
        systemctl enable NetworkManager
    fi
    if [ x"$(systemctl is-active NetworkManager)" != x"active" ]; then
        systemctl restart NetworkManager
    fi

    # 删除现有网络配置
    nmcli connection delete $(nmcli connection show |awk '{print $(NF-2)}')

    # 根据MAC遍历接口
    local ports=()
    for m in ${node_bond0_macs};do
        for i in $(nmcli device status |grep ethernet |awk '{print $1}');do 
            if [ $(nmcli device show $i |grep -i "${m}" |wc -l) -eq 1 ]; then
                local n=${#ports[@]}
                ports[${n}]="${i}"
                break
            fi
        done
    done

    # 创建bond0接口
    nmcli connection add type bond con-name bond0 ifname bond0 autoconnect yes bond.options "${node_bond0_mode}"
    nmcli connection modify bond0 ipv4.addresses ${node_bond0_ip}/${node_bond0_prefix} ipv4.gateway ${node_bond0_gw} ipv4.method manual

    # 绑定子接口
    for ((i=0;i<${#ports[@]};i++)); do
        nmcli connection add type ethernet con-name ${ports[${i}]} ifname ${ports[${i}]} master bond0
    done

    # 重载配置
    nmcli connection reload
    nmcli connection down bond0 && nmcli connection up bond0
}

add_repos(){
    # 增加软件源配置
    if [ -d /etc/yum.repos.d ]; then
        mkdir -p /etc/yum.repos.d/bak
        [ -d /etc/yum.repos.d/bak ] && mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak/
        cat > /etc/yum.repos.d/base.repo <<EOF
[os_base]
name=base packages
baseurl=http://172.16.1.1:8080/anolis/BaseOS
enabled=1
gpgcheck=0

[os_stream]
name=stream packages
baseurl=http://172.16.1.1:8080/anolis/AppStream
enabled=1
gpgcheck=0
EOF
    fi
}

security_base(){
    cd /root && curl --connect-timeout 5 -O http://172.16.1.1:8080/software/jixian-2023.tar.gz
    [ -f jixian-2023.tar.gz ] && tar zxf jixian-2023.tar.gz
    [ -d jixian-2023 ] && cd jixian-2023 && sh main.sh
}

setup_zbx_agent(){
    su - cloud -c "curl --connect-timeout 5 -O http://172.16.1.1:8080/software/zabbix_agentd_setup.sh"

    su - cloud -c "curl --connect-timeout 5 -O http://172.16.1.1:8080/software/zabbix_agentd_static.tar.gz"

    su - cloud -c "sh zabbix_agentd_setup.sh -s 172.16.1.1;sh zabbix_agentd/zabbix_script.sh restart"
}

main(){
    # 系统磁盘分区扩容
    resize_os_partition

    # 系统分区扩容
    create_rootvg_partition

    # 配置bond和ip
    net_setup_nmcli

    # 创建账号密码
    create_users

    # 配置软件源
    add_repos

    # 安装zabbix agent
    setup_zbx_agent

    # 基线加固
    security_base

    # 停用cloud-init
    systemctl disable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service

    reboot
}

main
