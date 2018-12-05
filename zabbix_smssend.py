#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import commands
import datetime


def Func_Logging(logging_type='false',
                 logging_file='app.log',
                 logging_msg='null'):
    if logging_type.lower() == 'true':
        with open(logging_file, 'a+') as f:
            f.write(logging_msg + '\n')
            f.close()


def Func_AlertConversion(alert_stat, alert_seve):
    # BMC status type: critical，major，minor，warn，ok
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


def Func_SMSSend():
    if (java_exec != '' and java_file != '' and opt_msginfo != ''
            and server_ip != '' and server_port != ''):
        msg_tmp = opt_msginfo.split('|')
        host_ip = msg_tmp[0]
        host_name = msg_tmp[1]
        event_id = msg_tmp[2]
        event_severity = msg_tmp[3]
        event_status = msg_tmp[4]
        event_name = msg_tmp[5]
        event_time = '\'' + msg_tmp[6] + '\''
        NP_num = '\'' + msg_tmp[7] + '\''
        sendmsg_value = ('\'' + event_status + ':' + host_name + '[' + host_ip
                         + '],Level:' + event_severity + ',' + event_name +
                         ',ID:' + event_id + '.' + '\'')
        alert_status = Func_AlertConversion(event_status, event_severity)
        sendmsg_tmp = (java_exec + ' -cp ' + java_file +
                       ' -Djava.security.policy=java.policy -Dnms_port=' +
                       server_port + ' -Dnms_host=' + server_ip +
                       ' com.ultrapower.ultranms.fault.EventClient -host ' +
                       host_ip + ' -instance ' + event_id +
                       ' -parameter VALUE -class CloudManage -status ' +
                       alert_status + ' -value ' + sendmsg_value +
                       ' -max 0 -min 0 -occurTime ' + event_time + NP_num)
        sendmsg_stat = commands.getstatusoutput(sendmsg_tmp)
        if sendmsg_stat[0] != 0:
            Func_Logging(logging_type, logging_file,
                         (str(datetime.datetime.now()) + ' [ERROR]: stat:' +
                          sendmsg_stat[0] + ' return msg:' + sendmsg_stat[1]) +
                         '\nscript information: ' + sendmsg_tmp)
        else:
            Func_Logging(
                logging_type, logging_file,
                (str(datetime.datetime.now()) + ' [INFO]: ' + sendmsg_stat[1])
                + '\nscript information: ' + sendmsg_tmp)


if __name__ == '__main__':
    os.chdir(sys.path[0])

    server_ip = '172.16.1.1'
    server_port = '88'
    java_file = sys.path[0] + '/' + 'extevent.jar'
    java_exec = '/bin/java'
    opt_msgsendto = ''
    opt_msgsubject = ''
    opt_msginfo = ''
    logging_type = 'false'
    logging_file = '/app_logs/1.log'

    try:
        opt_msgsendto = sys.argv[1]
        opt_msgsubject = sys.argv[2]
        opt_msginfo = sys.argv[3]
    except BaseException:
        pass
    Func_SMSSend()
