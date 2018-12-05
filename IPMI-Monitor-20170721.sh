#!/bin/bash

##################
#  基本参数配置  #
##################

# 设置ipmitool工具的执行路径
    ipmitoolpath="`which ipmitool`"
# 每天生成一个数据目录的名字，以年月日命名
    datadirname="`date '+%Y%m%d'`"
# 数据集的根目录设置
    basepath="/samba/healthreport"
# IP配置文件路径和名称，配置文件格式范例: IP|PORT|USERNAME|PASSWORD
    ipmiiplist="$basepath/tools/IPMI-IP-list.conf"
# report数据保存目录
    datasavepath="$basepath/sourcefiles/9_IPMI-check/$datadirname"
# 状态检测变量
    var_retval="0"
# ping检测，在线IP计数
    var_pingup="0"
# ping检测，离线IP计数
    var_pingdown="0"

#########################################################################################
#  report详细数据保存位置样式: $basepath/report/$datadirname/$HOST-report-$dateflag.txt  #
#########################################################################################

#判断ipmitool工具是否存在，不存在则直接退出
[ -z $ipmitoolpath ] && echo "$ipmitoolpath NOT FOUND." && exit 1

#判断数据根目录位置是否存在，不存在则直接退出
[ ! -d $basepath ] && echo "$basepath NOT FOUND." && exit 1

#判断ipmi ip配置文件是否存在，不存在则直接退出
[ ! -f $ipmiiplist ] && echo "$ipmiiplist NOT FOUND." && exit 1

#判断每天所需的数据文件目录是否存在，不存在则创建
if [ ! -d $datasavepath ]; then
    /bin/mkdir -p $datasavepath
fi


function ReportHeaderMsg(){
echo "

##############################
    Active   Host: $var_pingup
    Inactive Host: $var_pingdown
##############################

"
}

#ipmitool获取数据功能部分
function IPMIGetInfo(){

    # 1. 获取网络配置信息
    echo -e "\n\n[-]============Networking Configurations"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD lan print

    # 2. 获取chassis板卡状态
    echo -e "\n\n[-]============Chassis Status"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD chassis status

    # 3. 获取FRU板卡硬件信息，包括厂商品牌、硬件型号、序列号
    echo -e "\n\n[-]============Field Replaceable Unit"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD fru

    # 4. 获取MC软件版本信息
    echo -e "\n\n[-]============Management Controller Information"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD mc info

    # 5. 获取传感器数据信息
    echo -e "\n\n[-]============Sensor Data Repository"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sdr

    # 6. 获取传感器详细信息
    echo -e "\n\n[-]============Sensor Detailed Information"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sensor

    # 7. 获取系统日志信息
    echo -e "\n\n[-]============System Event Log"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list

    # 8. 获取IPMI用户列表信息
    echo -e "\n\n[-]============Management Users"
    $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD user list
}

function MakeSummary(){
    # 1. 检索传感器异常
    if [ $(${ipmitoolpath} -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sdr |grep -iEv "ok|ns" |wc -l) -ne "0" ]; then

        echo -e "\n\n============$HOST Sensor Warning,Error Information"
        $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sdr |grep -iEv "ok|ns"
    fi
    # 2. 检索最近4天的日志详细
    BeforeThreeDays=`date -d '-3 day' '+%x'`
    if [ $(${ipmitoolpath} -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeThreeDays} |wc -l) -ne "0" ]; then

        echo -e "\n\n============$HOST Last Logging"
        $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeThreeDays}
    fi
    BeforeTwoDays=`date -d '-2 day' '+%x'`
    if [ $(${ipmitoolpath} -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeTwoDays} |wc -l) -ne "0" ]; then

        echo -e "\n\n============$HOST Last Logging"
        $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeTwoDays}
    fi
    BeforeOneDays=`date -d '-1 day' '+%x'`
    if [ $(${ipmitoolpath} -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeOneDays} |wc -l) -ne "0" ]; then

        echo -e "\n\n============$HOST Last Logging"
        $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${BeforeOneDays}
    fi
    LastDays=`date '+%x'`
    if [ $(${ipmitoolpath} -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${LastDays} |wc -l) -ne "0" ]; then

        echo -e "\n\n============$HOST Last Logging"
        $ipmitoolpath -I lanplus -H $HOST -p $PORT -U $USER -P $PASSWD sel list |grep ${LastDays}
    fi
}

function PingFailedMsg(){
    echo -e "\n\n###### $HOST ping failed, please moving check. ######"
}

function PingCheck(){
    ping -c 2 $HOST &> /dev/null
    var_retval=$?
    if [ "$var_retval" -ne "0" ]; then
        ping -c 2 $HOST &> /dev/null
        var_retval=$?
    fi
    if [ "$var_retval" -eq "0" ]; then
        var_pingup=`expr $var_pingup + 1`
    else
        var_pingdown=`expr $var_pingdown + 1`
    fi
}

while read line
    do
        if [ ! -z `echo "$line" |sed '/^#/d' |sed '/^$/d'` ]; then
            dateflag="`date '+%Y%m%d%H%M'`"
            HOST=`echo $line |awk -F '|' '{print $1}'`
            PORT=`echo $line |awk -F '|' '{print $2}'`
            USER=`echo $line |awk -F '|' '{print $3}'`
            PASSWD=`echo $line |awk -F '|' '{print $4}'`
            echo > $datasavepath/$HOST-report-$dateflag.txt
            PingCheck
            if [ "$var_retval" -eq "0" ]; then
                IPMIGetInfo 2>&1 >> $datasavepath/$HOST-report-$dateflag.txt
                MakeSummary 2>&1 >> $datasavepath/IPMI-Summary-$datadirname.txt
                else
                PingFailedMsg 2>&1 >> $datasavepath/$HOST-report-$dateflag.txt
                PingFailedMsg 2>&1 >> $datasavepath/IPMI-Summary-$datadirname.txt
            fi
        fi
    done < $ipmiiplist

# 将summary文件复制到上级目录
if [ -f $datasavepath/IPMI-Summary-$datadirname.txt ]; then
    ReportHeaderMsg 2>&1 >> $datasavepath/IPMI-Summary-$datadirname.txt
    cp -f $datasavepath/IPMI-Summary-$datadirname.txt $datasavepath/../IPMI-Summary-today.txt
fi
