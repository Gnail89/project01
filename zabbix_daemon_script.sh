#!/bin/bash

basepath="%change_basepath%"

start_app(){
  if [ $(ps -ef |grep "${basepath}/sbin/zabbix_agentd" |grep -v grep |wc -l) -eq 0 ]; then
    if [ -r ${pidfile} ]; then
      /bin/rm -f "${pidfile}"
    fi
    ${basepath}/sbin/zabbix_agentd -c ${basepath}/etc/zabbix_agentd.conf &
  fi
}

stop_app(){
  if [ -r ${pidfile} ]; then
    /bin/kill -SIGTERM $(cat ${pidfile}) &>/dev/null
  else
    /bin/ps h -opid,cmd -C zabbix_agentd |egrep "${basepath}" |awk '{print $1}' |xargs -i kill {}
  fi
}

restart_app(){
  stop_app
  start_app
}

daemon_app(){
  if [ $(ps -ef |grep "${basepath}/sbin/zabbix_agentd" |grep -v grep |wc -l) -eq 0 ]; then
    restart_app
  fi
}

update_hostname(){
  local cfgFile="${basepath}/etc/zabbix_agentd.conf"
  if [ -w ${cfgFile} ]; then
    local cfgHostname="$(cat ${cfgFile} |egrep "^Hostname=" |awk -F '=' '{print $NF}')"
    local vmFlag="$(lscpu |egrep "Hypervisor[[:space:]]+vendor:[[:space:]]+(KVM|VMware)" |wc -l)"
    local ifname="$(awk '$2 == "00000000" {print $1}' /proc/net/route |sed -n '1p')"
    if [ x"${ifname}" != x"" ] && [ ${vmFlag} -gt 0 ]; then
      local n="$(/usr/sbin/ip addr show dev ${ifname} |egrep "192\.168\.[[:space:]]+\.[[:space:]]+" |wc -l)"
      if [ ${n} -eq 1 ]; then
        hostIP="$(/usr/sbin/ip addr show dev ${ifname} |egrep -o "192\.168\.[[:space:]]+\.[[:space:]]+" |sed -n '1p')"
      fi
    fi
    if [ x"${cfgHostname}" != x"" ] && [ x"${hostIP}" != x"" ]; then
      if [ x"${cfgHostname}" != x"${hostIP}" ]; then
        sed -i "s/^Hostname=.*$/Hostname=${hostIP}/g" ${cfgFile}
        if [ $(egrep "^Hostname=${hostIP}" ${cfgFile} |wc -l) -gt 0 ]; then
          restart_app
        fi
      fi
    fi
  fi
}

if [ -f ${basepath}/etc/zabbix_agentd.conf ]; then
  if [ -r ${basepath}/etc/zabbix_agentd.conf ]; then
    pidfile=$(egrep -v "^#|^$" ${basepath}/etc/zabbix_agentd.conf |grep PidFile |awk -F '=' '{print $NF}')
  else
    pidfile="/tmp/zabbix_agentd.pid"
  fi

  case "$1" in
    start)
      start_app
      ;;
    stop)
      stop_app
      ;;
    restart)
      restart_app
      ;;
    daemon)
      daemon_app
      update_hostname
      ;;
    *)
      echo $"Usage: $0 {start|stop|restart}"
      exit 1
      ;;
  esac
else
  echo "${basepath}/etc/zabbix_agentd.conf is not found"
fi
