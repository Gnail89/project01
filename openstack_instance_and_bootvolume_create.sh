#!/bin/bash
# Configuration file format:
# eg: "网络ID|IP地址|实例名称|指定的宿主机|虚拟机规格|镜像ID|卷类型名称|卷容量大小|"
# eg: "Network ID|IP Address|Instance Name|Zone host|Flavors Name|Image ID|Volume Type|Volume Size|"
. /root/admin-openrc
basepath=$(cd `dirname $0`;pwd)
log_dir="${basepath}/vm_and_bootvolume_create.log"
config_path="${basepath}/vm_and_bootvolume_create.conf"
var_retval=''

echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Start scripts." >> ${log_dir}
if [ ! -f ${config_path} ];then
    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: ${config_path} file not found." >> ${log_dir}
    exit 1
fi

Create_BootVolume(){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: start create volume of ${Volume_Name}" >> ${log_dir}
    if [ ! -z ${Image_Id} ] && [ ! -z ${Volume_Type} ] && [ ! -z ${Volume_Name} ] && [ ! -z ${Volume_Size} ]; then
        if [ $(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |wc -l) -eq 0 ]; then
            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: start cinder create --image_id ${Image_Id} --volume-type ${Volume_Type} --name ${Volume_Name} ${Volume_Size}" >> ${log_dir}
            /usr/bin/cinder create --image_id ${Image_Id} --volume-type ${Volume_Type} --name ${Volume_Name} ${Volume_Size} >> ${log_dir}
            var_retval=$?
            echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: status code is ${var_retval}" >> ${log_dir}
        else
            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: volume name is ${Volume_Name} , volume name was created." >> ${log_dir}
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Image_Id is ${Image_Id} , Volume_Type is ${Volume_Type} , Volume_Name is ${Volume_Name} info has an error." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ended create volume of ${Volume_Name}" >> ${log_dir}
}

Get_Volume_ID(){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: start get Volume ID of ${Volume_Name}" >> ${log_dir}
    if [ ! -z ${Volume_Name} ] && [ $(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |wc -l) -eq 1 ] ; then
        VolumeId=$(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |awk -F '|' '{print $2}' |awk '{print $1}')
        var_retval=$?
        echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: status code is ${var_retval} , VolumeId is ${VolumeId}" >> ${log_dir}
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: Volume_Name is ${Volume_Name} is not available." >>${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ended get Volume ID of ${Volume_Name}" >> ${log_dir}
}

Create_Instance(){
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: start create instance of ${Volume_Name}" >> ${log_dir}
    if [ ! -z ${VolumeId} ] && [ ! -z ${IP_Addr} ] && [ ! -z ${VMName} ] && [ ! -z ${Zone_Host} ] && [ ! -z ${Flavors_Name} ]; then
        if [ $(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |wc -l) -eq 1 ]; then
            if [ $(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |awk -F '|' '{print $3}' |awk '{print $1}') == "available" ]; then
                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: start nova boot --flavor ${Flavors_Name} --boot-volume ${VolumeId} --availability-zone ${Zone_Host} --nic net-id=${NetworkId},v4-fixed-ip=${IP_Addr} ${VMName}" >> ${log_dir}
                /usr/bin/nova boot --flavor ${Flavors_Name} --boot-volume ${VolumeId} --availability-zone ${Zone_Host} --nic net-id=${NetworkId},v4-fixed-ip=${IP_Addr} ${VMName} >> ${log_dir}
                var_retval=$?
                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: status code is ${var_retval}" >> ${log_dir}
            else
                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: $(/usr/bin/cinder list --name ${Volume_Name}) \n\n volume is not available." >>${log_dir}
            fi
        else
            echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: volume name is ${Volume_Name} , there are multiple values." >>${log_dir}
        fi
    else
        echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: VolumeId is ${VolumeId} , IP_Addr is ${IP_Addr} , vm_name is ${VMName} , zome_host is ${Zone_Host} , flavors_name is ${Flavors_Name} info has an error." >> ${log_dir}
    fi
    echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: ended create instance of ${Volume_Name}" >> ${log_dir}
}

while read line
    do
        if [ ! -z `echo ${line} |sed '/^#/d' |sed '/^$/d'` ]; then
            # Configuration file format:
            # eg: "网络ID|IP地址|实例名称|指定的宿主机|虚拟机规格|镜像ID|卷类型名称|卷容量大小|"
            # eg: "Network ID|IP Address|Instance Name|Zone host|Flavors Name|Image ID|Volume Type|Volume Size|"
            NetworkId=`echo $line |awk -F '|' '{print $1}'`
            IP_Addr=`echo $line |awk -F '|' '{print $2}'`
            VMName=`echo $line |awk -F '|' '{print $3}'`
            Zone_Host=`echo $line |awk -F '|' '{print $4}'`
            Flavors_Name=`echo $line |awk -F '|' '{print $5}'`
            Image_Id=`echo $line |awk -F '|' '{print $6}'`
            Volume_Type=`echo $line |awk -F '|' '{print $7}'`
            Volume_Size=`echo $line |awk -F '|' '{print $8}'`
            Volume_Name="${VMName}-bootvolume"
            VolumeId=""
            # Start create bootable volume
            Create_BootVolume
            # Get volume ID by name
            Get_Volume_ID
            while true
            do
                if [ $(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |wc -l) -eq 1 ]; then
                        VolumeStatus="$(/usr/bin/cinder list --name ${Volume_Name} |grep ${Volume_Name} |awk -F '|' '{print $3}' |awk '{print $1}')"
                        case ${VolumeStatus} in
                            available)
                                sleep 30
                                # Create instance and poweron
                                Create_Instance
                                sleep 30
                                break
                            ;;
                            creating)
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: volume name is ${Volume_Name} , volume status is ${VolumeStatus} , volume is not available." >> ${log_dir}
                                sleep 60
                            ;;
                            downloading)
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: volume name is ${Volume_Name} , volume status is ${VolumeStatus} , volume is not available." >> ${log_dir}
                                sleep 60
                            ;;
                            'in-use')
                                echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: volume name is ${Volume_Name} , volume status is ${VolumeStatus} , volume has been used." >> ${log_dir}
                                break
                            ;;
                            *)
                                echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: volume name is ${Volume_Name} , volume status is ${VolumeStatus} , volume status error." >>${log_dir}
                                break
                            ;;
                        esac
                else
                    echo "`date +'%Y-%m-%d %H:%M:%S'` ERROR: volume name is ${Volume_Name} , there are multiple values." >>${log_dir}
                    break
                fi
            done
        fi
    done < ${config_path}
echo "`date +'%Y-%m-%d %H:%M:%S'` INFO: Ended scripts." >> ${log_dir}
