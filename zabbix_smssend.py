#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import re
import commands
import datetime


def logger(log_type='false', log_file='app.log', log_msg='null'):
    if log_type.lower() == 'true':
        with open(log_file, 'a+') as f:
            f.write(log_msg + '\n')
            f.close()


def alert_conversion(alert_stat, alert_seve):
    # BOMC status type: critical，major，minor，warn，ok
    if alert_stat == 'PROBLEM':
        if alert_seve == 'Disaster':
            return 'critical'
        elif alert_seve == 'High':
            return 'critical'
        elif alert_seve == 'Average':
            return 'major'
        elif alert_seve == 'Warning':
            return 'major'
    elif alert_stat == 'RESOLVED':
        return 'OK'
    else:
        return 'NULL'


def msg_filter(self):
    filter_group = ['NOTE: Escalation cancelled:']
    arr = self.splitlines()
    flag = False
    t = 0
    m = 0
    while m < len(arr):
        n = 0
        while n < len(filter_group):
            if re.search(filter_group[n], arr[m]):
                t = m + 1
                flag = True
                break
            n += 1
        if flag:
            break
        else:
            m += 1
    if flag:
        msg_tmp = arr[t].split('|')
        msg_tmp[0] = 'RESOLVED'
        return msg_tmp
    else:
        msg_tmp = arr[0].split('|')
        return msg_tmp


def sms_sender():
    if (java_exec != '' and java_file != '' and opt_msginfo != ''
            and server_ip != '' and server_port != ''):
        msg_tmp = msg_filter(opt_msginfo)
        event_status = msg_tmp[0]
        host_name = msg_tmp[1]
        host_ip = msg_tmp[2]
        event_severity = msg_tmp[3]
        event_name = msg_tmp[4]
        event_id = msg_tmp[5]
        event_time = '\'' + msg_tmp[6] + '\''
        NP_num = msg_tmp[7]
        payload = ('\'' + host_name + '[' + host_ip + '],Level:' +
                   event_severity + ',' + event_name + '.\'')
        alert_status = alert_conversion(event_status, event_severity)
        exec_cmd = (java_exec + ' -cp ' + java_file +
                    ' -Djava.security.policy=java.policy -Dnms_port=' +
                    server_port + ' -Dnms_host=' + server_ip +
                    ' com.ultrapower.ultranms.fault.EventClient -host ' +
                    host_ip + ' -instance ' + event_id +
                    ' -parameter VALUE -class CloudZabbix -status ' +
                    alert_status + ' -value ' + payload +
                    ' -max 0 -min 0 -occurTime ' + event_time + NP_num)
        sendmsg_stat = commands.getstatusoutput(exec_cmd)
        if sendmsg_stat[0] != 0:
            logger(log_type, log_file,
                   (str(datetime.datetime.now()) + ' [ERROR]: ErrorCode: ' +
                    str(sendmsg_stat[0]) + ', ErrorInfo: ' + sendmsg_stat[1]) +
                   '\nCommands: ' + exec_cmd)
        else:
            logger(log_type, log_file,
                   (str(datetime.datetime.now()) + ' [INFO]: ' +
                    sendmsg_stat[1]) + '\nCommands: ' + exec_cmd)


if __name__ == '__main__':
    os.chdir(sys.path[0])
    server_ip = '172.16.1.1'
    server_port = '88'
    java_file = sys.path[0] + '/' + 'extevent.jar'
    java_exec = '/bin/java'
    opt_msgsendto = ''
    opt_msgsubject = ''
    opt_msginfo = ''
    log_type = 'false'
    log_file = '/app_logs/1.log'

    try:
        opt_msgsendto = sys.argv[1]
        opt_msgsubject = sys.argv[2]
        opt_msginfo = sys.argv[3]
    except BaseException:
        pass
    sms_sender()
