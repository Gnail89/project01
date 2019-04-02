#!/bin/bash

basepath=$(cd `dirname $0`;pwd)

ssh_port="22"
special_user="username"
login_success=0
login_fail=0

ip_addr_list="${basepath}/user_rcks_ip_list.txt"
expect_script="${basepath}/user_rcks.exp"
expect_log="${basepath}/user_rcks.exp.log"

if [ ! -f /usr/bin/expect ]; then
    echo -e "\n/usr/bin/expect command not found"
    exit 1
fi

if [ ! -f ${ip_addr_list} ]; then
    echo -e "${ip_addr_list} file not found"
    exit 1
fi

while read line;do
    if [ $(echo ${line} |sed '/^#/d' |sed '/^$/d' |wc -l) -eq 1 ]; then
        ip_addr=$(echo ${line} |awk '{print $1}')
        user_name=$(echo ${line} |awk '{print $2}')
        user_pwd=$(echo ${line} |awk '{print $3}')
        curl -o /dev/null -s --connect-timeout 1 ${ip_addr}:${ssh_port}
        if [ $? -eq 56 ]; then
            expect ${expect_script} "${ip_addr}" "${ssh_port}" "${user_name}" "${user_pwd}" "${expect_log}" &>/dev/null
            if [ -f ${expect_log} ]; then
                if [ x"${user_name}" == x"${special_user}" ]; then
                    if [ $(grep -i "^Permission denied" ${expect_log} |wc -l) -eq 1 ]; then
                        ((login_fail=${login_fail}+1))
                        echo -e "\n${ip_addr} ${user_name} login faied"
                    elif [ $(grep -w "^user_check_login_status_ok" ${expect_log} |wc -l) -eq 1 ]; then
                        ((login_success=${login_success}+1))
                        if [ $(grep -w "^user_check_cat_permit_status_ok" ${expect_log} |wc -l) -eq 1 ]; then
                            if [ $(egrep -v "^#|^$" ${expect_log} |grep ${special_user} |grep -w NOPASSWD |grep -w useradd |grep -w userdel |grep -w usermod |grep -w passwd |grep -w groupadd |grep -w groupdel |grep -w cat |wc -l) -ne 0 ] ;then
                                echo -e "\n${ip_addr} ${user_name} success"
                            else
                                echo -e "\n${ip_addr} ${user_name} sudo setting error"
                            fi
                        elif [ $(grep -w "^user_check_cat_permit_status_failed" ${expect_log} |wc -l) -eq 1 ]; then
                            echo -e "\n${ip_addr} ${user_name} sudo cat file, permission deny"
                        else
                            echo -e "\n${ip_addr} ${user_name} inspect failed"
                        fi
                    else
                        ((login_fail=${login_fail}+1))
                        echo -e "\n${ip_addr} ${user_name} inspect failed"
                    fi
                else
                    if [ $(grep -i "^Permission denied" ${expect_log} |wc -l) -eq 1 ]; then
                        ((login_fail=${login_fail}+1))
                        echo -e "\n${ip_addr} ${user_name} login faied"
                    elif [ $(grep -w "^user_check_login_status_ok" ${expect_log} |wc -l) -eq 1 ]; then
                        ((login_success=${login_success}+1))
                        echo -e "\n${ip_addr} ${user_name} login success"
                    else
                        ((login_fail=${login_fail}+1))
                        echo -e "\n${ip_addr} ${user_name} inspect failed"
                    fi
                fi
            fi
        else
            echo -e "\n${ip_addr} port ${ssh_port} connect failed"
        fi
        if [ -f ${expect_log} ]; then
            cat /dev/null > ${expect_log}
        fi
    fi
done < ${ip_addr_list}
echo -e "\n  Total: ${login_success} success, ${login_fail} failed"
