#!/bin/bash
# yum install ipset-service && systemctl enable ipset && systemctl start ipset
# ipset save > /etc/sysconfig/ipset
# * * * * * /bin/bash /opt/ban_ssh_ip.sh &>/dev/null
# -A INPUT -p tcp -m set --match-set banlist src -m tcp --dport 22 -m comment --comment "block ipset banlist" -j DROP

ipset_name="banlist"
num=3
date_time="$(date -d "1 hours ago" "+%Y-%m-%d %H:%M:%S")"

[[ $(ipset list ${ipset_name}) ]] || ipset create ${ipset_name} hash:ip maxelem 1000 timeout 3600

ipset_info="$(ipset save ${ipset_name})"

lastb -a -s "${date_time}" |awk '/ssh/{print $NF}' |sort -n |uniq -c |while read line; do
    count="$(echo $line |awk '{print $1}')"
    ipaddr="$(echo $line |awk '{print $2}')"
    if [ $count -ge $num ] && [ $(echo ${ipset_info} |grep -wc "${ipaddr}") -eq 0 ]; then
        /usr/sbin/ipset add ${ipset_name} ${ipaddr}
    fi
done
