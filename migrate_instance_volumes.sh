#!/bin/bash

while read vm_ip;do
    [ -f rebuild_${vm_ip}_volumes.data ] && rm -f rebuild_${vm_ip}_volumes.data
    echo "review rebuild instance info:"
    sh output_openstack_vm_rebuild_cmd.sh --ip ${vm_ip}$ &> rebuild_${vm_ip}.log
    vm_id="$(openstack server list -f value -c ID --ip ${vm_ip}$)"
    vm_name="$(openstack server show -f value -c name ${vm_id})"
    e_flavor="$(openstack server show -f value -c flavor ${vm_id} |awk '{print $1}')"
    e_vlan="$(openstack server show -f value -c addresses ${vm_id} |awk -F'=' '{print $1}')"
    e_ip="$(openstack server show -f value -c addresses ${vm_id} |awk -F'=' '{print $2}')"
    e_hypervisor="$(openstack server show -f value -c OS-EXT-SRV-ATTR:host ${vm_id})"
    
    vm_volumes="$(openstack server show -f value -c volumes_attached ${vm_id} |sed -e "s/id=//g" -e "s/'//g")"
    
    echo "stop instance ${vm_id}" && nova stop ${vm_id}
    echo "wait 120 sec" && sleep 120
    
    for i in {1..10};do
        if [ x"$(openstack server show -f value -c status ${vm_id})" == x"SHUTOFF" ]; then
            echo "instance SHUTOFF: ${vm_id}"
            break
        else
            echo "wait 60 sec" && sleep 60
        fi
    done
    
    echo "rename instance" && openstack server set --name "${vm_name}-offline" ${vm_id}
    
    for i in ${vm_volumes};do
        vol_id="$i"
        vol_name="$(openstack volume show -f value -c name ${vol_id})"
        vol_size="$(openstack volume show -f value -c size ${vol_id})"
        echo "create image from volume, vol_id: ${vol_id}"
        openstack volume set --state available ${vol_id}
        echo "volume status: $(openstack volume show -f value -c status ${vol_id})"
        echo "wait 60 sec" && sleep 60
        #vol_img_id="$(openstack image create -f value -c image_id --container-format bare --disk-format qcow2 --volume ${vol_id} --force "new-${vol_name}")"
        
        echo ""
        echo ""
        echo "################### Run Command Now #############################"
        echo ""
        #echo "openstack image create -f value -c image_id --container-format bare --disk-format qcow2 --volume ${vol_id} --force \"new-${vol_name}\""
        echo "openstack image create -f value -c image_id --container-format bare --disk-format qcow2 --volume ${vol_id} --force \"new-${vol_name}\" >  rebuild_new_image_id.data"
        echo ""
        echo "########## Save image id to file: rebuild_new_image_id.data #############"
        echo ""
        echo ""

        [ -f rebuild_new_image_id.data ] && rm -f rebuild_new_image_id.data
        
        for i in {1..200};do
            if [ -r "rebuild_new_image_id.data" ]; then
                vol_img_id="$(cat rebuild_new_image_id.data)"
                if [ x"${vol_img_id}" != x"" ]; then
                    break
                else
                    vol_img_id=""
                fi
            else
                vol_img_id=""
            fi
            sleep 60
        done
        
        echo "Update: volume id: ${vol_id}, New Image id: ${vol_img_id}"
        [ x"${vol_img_id}" == x"" ] && echo "create new image failed" && exit 0
        echo "wait 300 sec" && sleep 300
        
        for i in {1..200};do
            img_stat="$(openstack image show -f value -c status ${vol_img_id})"
            if [ x"${img_stat}" == x"active" ]; then
                echo "image upload done, image id: ${vol_img_id}, status: ${img_stat}"
                new_vol_id="$(openstack volume create -f value -c id --size ${vol_size} --image ${vol_img_id} --type hw "new-${vol_name}")"
                echo "${new_vol_id}" >> rebuild_${vm_ip}_volumes.data
                echo "create new volume at hw pool, new volume id: ${new_vol_id}"
                openstack volume set --state in-use ${vol_id}
                break
            else
                echo "wait 300 sec, image id: ${vol_img_id}, status: ${img_stat}" && sleep 300
            fi
        done
    done
    echo "NOTE: all volume migation done, see file: rebuild_${vm_ip}_volumes.data"
    
    echo "wait volumes become to available state"
    for i in {1..200}; do
        m=0
        mm="$(egrep -v "^#|^$" rebuild_${vm_ip}_volumes.data |wc -l)"
        for v in $(cat rebuild_${vm_ip}_volumes.data);do
            vv="$(openstack volume show -f value -c status ${v})"
            if [ x"${vv}" == x"available" ]; then
                m=$(( $m + 1 ))
            fi
        done
        if [ x"${m}" == x"${mm}" ]; then
            echo "NOTE: all volumes become to available, volumes available stat count: $m / $mm"
            break
        else
            echo "wait 300 sec, volumes available stat count: $m / $mm" && sleep 300
        fi
    done
    
    echo "boot new instance"
    
    e_volume=""
    n=0
    for ii in $(cat rebuild_${vm_ip}_volumes.data);do
        e_volume="${e_volume} --block-device source=volume,id=${ii},dest=volume,shutdown=preserve,bootindex=${n}"
        n=$(( $n + 1 ))
    done
    
    echo "Detach interface in instance"
    nova interface-detach ${vm_id} "$(openstack port list -f value -c ID --server ${vm_id})"
    echo "wait 60 sec" && sleep 60
    
    if [ -r rebuild_${vm_ip}_hypervisor.data ]; then
        h="$(egrep -v "^#|^$" rebuild_${vm_ip}_hypervisor.data)"
        if [ x"${h}" != x"" ]; then
            e_hypervisor="$h"
            echo "New hypervisor host: ${e_hypervisor}"
        else
            echo "New hypervisor not found, keep old one: ${e_hypervisor}"
        fi
    else
        echo "Useing old hypervisor host: ${e_hypervisor}"
    fi

    echo "Rebuild Command is:"
    echo ""
    echo "nova boot --flavor ${e_flavor} ${e_volume} --nic net-name=\"${e_vlan}\",v4-fixed-ip=${e_ip} --availability-zone nova:${e_hypervisor} \"${vm_name}-new\""

    nova boot --flavor ${e_flavor} ${e_volume} --nic net-name="${e_vlan}",v4-fixed-ip=${e_ip} --availability-zone nova:${e_hypervisor} "${vm_name}-new"

done < ip.txt
