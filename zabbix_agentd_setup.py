#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import platform
import urllib
import urllib2
import commands
import random
import string
import socket
import re


def Get_OS_Version():
    '''format: ('Linux', 'centos', '6.7', '64bit')'''
    return (platform.system(), platform.dist()[0], platform.dist()[1],
            platform.architecture()[0])


def Download_App():
    f = urllib2.urlopen(zabbix_agentd_dlurl)
    data = f.read()
    with open(zabbix_agentd_dlfilename, "wb") as code:
        code.write(data)
        code.close()


def Add_Crontab_Policy():
    crontab_comm = "crontab -l -u " + zabbix_agentd_user
    crontab_status = commands.getstatusoutput(crontab_comm)
    crontab_tag = 0
    if crontab_status[0] == 0:
        crontab_tmpfile = ''.join(
            random.sample(string.ascii_letters + string.digits, 8))
        with open(crontab_tmpfile, 'w+') as f:
            f.write(crontab_status[1] + '\n')
            f.close()
        with open(crontab_tmpfile, 'r+') as f:
            for line in f.readlines():
                if re.search((r'^[^#].*' + zabbix_agentd_daemon_path), line):
                    crontab_tag = 1
                    break
            f.close()
        if crontab_tag == 0:
            with open(crontab_tmpfile, 'a+') as f:
                f.write(zabbix_crond_policy + '\n')
                f.close()
            if os.path.exists(crontab_tmpfile):
                commands.getstatusoutput("crontab -u " + zabbix_agentd_user +
                                         " " + crontab_tmpfile)
            else:
                print(crontab_tmpfile + " file not found")
                sys.exit()
        if os.path.exists(crontab_tmpfile):
            os.remove(crontab_tmpfile)
    elif crontab_status[0] != 0 and crontab_status[
            1] == 'no crontab for ' + zabbix_agentd_user:
        crontab_tmpfile = ''.join(
            random.sample(string.ascii_letters + string.digits, 8))
        with open(crontab_tmpfile, 'w+') as f:
            f.write(zabbix_crond_policy + '\n')
            f.close()
        if os.path.exists(crontab_tmpfile):
            commands.getstatusoutput("crontab -u " + zabbix_agentd_user + " " +
                                     crontab_tmpfile)
        else:
            print(crontab_tmpfile + " file not found")
            sys.exit()
        if os.path.exists(crontab_tmpfile):
            os.remove(crontab_tmpfile)
    else:
        print(crontab_comm + " Command execution failed")
        sys.exit()


def Setup_ZabbixAgentd():
    if os.path.exists(zabbix_agentd_dlfilename):
        setup_status = commands.getstatusoutput("tar -C /usr/local/ -zxf " +
                                                zabbix_agentd_dlfilename)
        if setup_status[0] == 0:
            os.remove(zabbix_agentd_dlfilename)
            setup_status = commands.getstatusoutput("chown -R " +
                                                    zabbix_agentd_user + " " +
                                                    zabbix_agentd_install_path)
            if setup_status[0] != 0:
                print("Change permission on " + zabbix_agentd_install_path +
                      " was failed")
                sys.exit()
        else:
            print(zabbix_agentd_dlfilename + " Unpacking failed")
            sys.exit()
    else:
        print(zabbix_agentd_dlfilename + " file not found")
        sys.exit()


def Get_OS_IPAddr(network_type):
    if network_type == 'public':
        return ([(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close())
                 for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]
                 ][0][1])
    elif network_type == 'internal':
        return ([(s.connect(('172.16.1.1', 53)), s.getsockname()[0], s.close())
                 for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]
                 ][0][1])


def Setup_ZabbixAgentd_cfgfile(setup_cfgfile_tag, setup_cfgfile_value):
    if os.path.exists(zabbix_agentd_cfgfile_path):
        w_str = ''
        with open(zabbix_agentd_cfgfile_path, 'r') as f:
            for line in f.readlines():
                if re.search(setup_cfgfile_tag, line):
                    line = re.sub(setup_cfgfile_tag, setup_cfgfile_value, line)
                    w_str += line
                else:
                    w_str += line
            f.close()
        with open(zabbix_agentd_cfgfile_path, 'w') as f:
            f.write(w_str)
            f.close()


def VerifyUser():
    verify_status = commands.getstatusoutput('id ' + zabbix_agentd_user)
    if verify_status[0] != 0:
        print(zabbix_agentd_user + ' user does not exist')
        sys.exit()


def HelpInfo():
    print('''optional arguments:
    <public,internal>
                          Choose network type: public, internal
    [offline]             Offline installation option, current directory
                          installation''')


def main():
    VerifyUser()
    host_ipaddr = Get_OS_IPAddr(network_opt)
    if offline_opt != 'offline':
        Download_App()
    Setup_ZabbixAgentd()
    Setup_ZabbixAgentd_cfgfile(zabbix_agentd_cfgfile_hostname, host_ipaddr)
    Setup_ZabbixAgentd_cfgfile(zabbix_agentd_cfgfile_sourceip, host_ipaddr)
    Add_Crontab_Policy()


if __name__ == '__main__':
    os.chdir(sys.path[0])
    network_opt = ''
    offline_opt = ''
    try:
        network_opt = sys.argv[1]
    except BaseException:
        pass
    try:
        offline_opt = sys.argv[2]
    except BaseException:
        pass

    zabbix_agentd_user = 'username'
    zabbix_agentd_dlfilename = 'zabbix_agentd_static.tar.gz'
    zabbix_agentd_install_path = '/usr/local/zabbix_agentd'
    zabbix_agentd_daemon_path = (
        zabbix_agentd_install_path + '/zabbix_agentd_daemon.sh')
    zabbix_crond_policy = ('*/10 * * * * /bin/sh ' + zabbix_agentd_daemon_path
                           + ' 2>&1 >/dev/null')
    zabbix_agentd_cfgfile_path = (
        zabbix_agentd_install_path + '/etc/zabbix_agentd.conf')
    zabbix_agentd_cfgfile_hostname = '%change_hostname%'
    zabbix_agentd_cfgfile_sourceip = '%change_sourceip%'

    if network_opt == 'public':
        zabbix_agentd_dlurl = (
            'http://mirrors.163.com/centos/7/isos/x86_64/0_README.txt')
    elif network_opt == 'internal':
        zabbix_agentd_dlurl = (
            'http://mirrors.163.com/centos/7/isos/x86_64/0_README.txt')
    else:
        print('usage: ' + sys.argv[0] + ' <public, internal> [offline]')
        HelpInfo()
        sys.exit()

    os_platform_info = Get_OS_Version()
    if os_platform_info[0] == 'Linux':
        if os_platform_info[1].lower() == 'centos':
            if os_platform_info[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        elif os_platform_info[1].lower() == 'redhat':
            if os_platform_info[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        elif os_platform_info[1].lower() == 'suse':
            if os_platform_info[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        else:
            print(os_platform_info[1] + " Operating system is not supported")
            sys.exit()
    elif os_platform_info[0] == 'Windows':
        print(os_platform_info[0] + " Platform is not supported")
        sys.exit()
    else:
        print(os_platform_info[0] + " Platform is not supported")
        sys.exit()
