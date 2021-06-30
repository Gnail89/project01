#!/bin/bash

m_user="username"
m_pwd="password"
m_db="zabbix"
m_host="ipaddr"
m_port="3306"
m_socket="mysql-socket"
mysql_bin="mysql"

MYSQL_CMD=$(echo ${mysql_bin} -u${m_user} -p${m_pwd} -P${m_port} -h${m_host} -S${m_socket} ${m_db})

see_data(){
    local ipaddr="$1"
    local item_id="$2"
    local table_name="$3"
    local SQL1=$(echo "select value from ${table_name} where itemid = ${item_id} order by value DESC limit 1;")
    local value_tmp="$(${MYSQL_CMD} -e "${SQL1}" 2>/dev/null |egrep "[[:digit:]]+")"
    if [ x"${value_tmp}" != x"" ]; then
        echo "${ipaddr} ${item_id} ${value_tmp}"
    else
        echo "${ipaddr} ${item_id} null"
    fi
}

main(){
    local SQL1=$(echo "select hosts.host,items.itemid,items.value_type from items,hosts where items.name like '%进风口温度%' and items.hostid = hosts.hostid;")
    echo "$(${MYSQL_CMD} -e "${SQL1}" 2>/dev/null |egrep "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+")" |while read line;do
        local ipaddr="$(echo ${line} |awk '{print $1}')"
        local itemid="$(echo ${line} |awk '{print $2}')"
        local value_type="$(echo ${line} |awk '{print $3}')"
        case "${value_type}" in
            0)
                see_data "${ipaddr}" "${itemid}" "history"
                ;;
            1)
                see_data "${ipaddr}" "${itemid}" "history_str"
                ;;
            2)
                see_data "${ipaddr}" "${itemid}" "history_log"
                ;;
            3)
                see_data "${ipaddr}" "${itemid}" "history_uint"
                ;;
            4)
                see_data "${ipaddr}" "${itemid}" "history_text"
                ;;
            *)
                echo "unknown value type"
                ;;
        esac
    done
}

main
