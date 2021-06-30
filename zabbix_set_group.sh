#!/bin/bash

user="123456"
passwd="123456"
url="http://site/zabbix/api_jsonrpc.php"


get_token(){
    payload="{ \"jsonrpc\": \"2.0\", \"method\": \"user.login\", \"params\": { \"user\": \"${user}\", \"password\": \"${passwd}\" }, \"id\": 2021, \"auth\": null }"
    token="$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d \"${payload}\" ${url} |python -m json.tool |egrep "result" |awk -F'\"' '{print $4}')"
}


set_group(){
    if [ x"${token}" != x"" ]; then
        while read line;do
            local hostname="$(echo $line |awk -F'|' '{print $1}')"
            local group_id="$(echo $line |awk -F'|' '{print $2}')"
            if [ x"${hostname}" != x"" ]; then
                local payload="{ \"jsonrpc\": \"2.0\", \"method\": \"host.get\", \"params\": { \"output\": [\"hostid\"], \"filter\": { \"host\": [\"${hostname}\"] } }, \"id\": 2021, \"auth\": \"${token}\" }"
                local host_id="$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d \"${payload}\" ${url} |python -m json.tool |egrep "hostid" |awk -F'\"' '{print $4}')"
                if [ x"${host_id}" != x"" ]; then
                    local payload="{ \"jsonrpc\": \"2.0\", \"method\": \"host.update\", \"params\": { \"hostid\": \"${host_id}\", \"groups\": \"${group_id}\" }, \"auth\": \"${token}\", \"id\": 2021 }"
                    local res="$(curl -s -X POST -H 'Content-Type: application/json-rpc' -d \"${payload}\" ${url} |python -m json.tool |egrep -wc "${host_id}")"
                    if [ "${res}" -eq 1 ]; then
                        echo "host ${hostname} set ${group_id} is ok"
                    else
                        echo "host ${hostname} set ${group_id} is failed"
                    fi
                fi
            fi
        done < ip_list.txt
    else
        echo "token error"
    fi
}

get_token
set_group
