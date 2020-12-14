#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import platform
import urllib2
import commands
import random
import string
import socket
import re
import getpass


def help_info():
    print('usage:')
    print('    ' + sys.argv[0] + ' -s ipaddr')
    print('    ' + sys.argv[0] + ' [-u user_name] -s ipaddr')
    print('    ' + sys.argv[0] + ' [-u user_name] [-d directory] -s ipaddr')
    print('''Options:
    -u user_name
                Which user to install program, default value: 'cloud'
    -d directory
                The top of the installation directory, default value: '$HOME'
    -s ipaddr
                Server/Proxy IP address''')


try:
    gl_var_dict = {}
    serverIP = ''
    getPath = os.environ['HOME']
    gl_var_dict['targetUser'] = 'cloud'
    for n in range(1, len(sys.argv[1:]) + 1, 2):
        if sys.argv[n] == '-u':
            gl_var_dict['targetUser'] = sys.argv[n + 1]
        elif sys.argv[n] == '-s':
            serverIP = sys.argv[n + 1]
        elif sys.argv[n] == '-d':
            getPath = sys.argv[n + 1]
            if not os.path.exists(getPath):
                print(getPath + ': Path does not exist')
                sys.exit()
            elif not os.access(getPath, os.W_OK):
                print(getPath + ': Permission denied')
                sys.exit()
        elif sys.argv[n] == '-h':
            help_info()
            sys.exit()
        else:
            print('Invalid parameter detected.')
            help_info()
            sys.exit()
    getPath = re.sub(r'/+$', '', getPath)
    gl_var_dict['srcFilename'] = 'zabbix_agentd_static.tar.gz'
    gl_var_dict['resServers'] = [['172.16.1.1', '80'], ['172.16.1.2', '80']]
    gl_var_dict['rootPath'] = getPath
    gl_var_dict['instDirName'] = getPath + '/zabbix_agentd'
    gl_var_dict['daemonScript'] = getPath + '/zabbix_agentd/zabbix_script.sh'
    gl_var_dict[
        'cronPolicy'] = '*/10 * * * * /bin/sh ' + getPath + '/zabbix_agentd/zabbix_script.sh daemon 2>&1 >/dev/null'
    gl_var_dict[
        'configFile'] = getPath + '/zabbix_agentd/etc/zabbix_agentd.conf'
    gl_var_dict[
        'userParameterPath'] = getPath + '/zabbix_agentd/etc/zabbix_agentd.conf.d'
except Exception:
    print('Failed to initialize parameters')
    sys.exit()


def get_os_version():
    '''format: ('Linux', 'centos', '6.7', '64bit')'''
    return (platform.system(), platform.dist()[0], platform.dist()[1],
            platform.architecture()[0])


def diag_server_status(ip, port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        if s.connect_ex((ip, int(port))) == 0:
            print(ip + ":" + port + " connection success.")
            return True
        else:
            print(ip + ":" + port + " connection failed.")
            return False
        s.close()
    except BaseException:
        pass


def download_package(ip, port):
    f = urllib2.urlopen('http://' + ip + ':' + port +
                        '/centos/7/isos/x86_64/' + gl_var_dict['srcFilename'])
    data = f.read()
    with open(gl_var_dict['srcFilename'], "wb") as code:
        code.write(data)
        code.close()


def add_cron_policy():
    crontab_comm = "crontab -l"
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
                if re.search((r'^[^#].*' + gl_var_dict['daemonScript']), line):
                    crontab_tag = 1
                    break
            f.close()
        if crontab_tag == 0:
            with open(crontab_tmpfile, 'a+') as f:
                f.write(gl_var_dict['cronPolicy'] + '\n')
                f.close()
            if os.path.exists(crontab_tmpfile):
                commands.getstatusoutput("crontab " + crontab_tmpfile)
            else:
                print(crontab_tmpfile + " file not found")
                sys.exit()
        if os.path.exists(crontab_tmpfile):
            os.remove(crontab_tmpfile)
    elif crontab_status[0] != 0 and re.search(r'no crontab for',
                                              crontab_status[1]):
        crontab_tmpfile = ''.join(
            random.sample(string.ascii_letters + string.digits, 8))
        with open(crontab_tmpfile, 'w+') as f:
            f.write(gl_var_dict['cronPolicy'] + '\n')
            f.close()
        if os.path.exists(crontab_tmpfile):
            commands.getstatusoutput("crontab " + crontab_tmpfile)
        else:
            print(crontab_tmpfile + " file not found")
            sys.exit()
        if os.path.exists(crontab_tmpfile):
            os.remove(crontab_tmpfile)
    else:
        print(crontab_comm + " Command execution failed")
        sys.exit()


def decompress_packages():
    if os.path.exists(gl_var_dict['srcFilename']):
        setup_status = commands.getstatusoutput("tar -C " +
                                                gl_var_dict['rootPath'] +
                                                " -zxf " +
                                                gl_var_dict['srcFilename'])
        if setup_status[0] == 0:
            os.remove(gl_var_dict['srcFilename'])
            setup_status = commands.getstatusoutput("chown -R " +
                                                    gl_var_dict['targetUser'] +
                                                    " " +
                                                    gl_var_dict['instDirName'])
            if setup_status[0] != 0:
                print("Change permission on " + gl_var_dict['instDirName'] +
                      " was failed")
                sys.exit()
        else:
            print(gl_var_dict['srcFilename'] + " Unpacking failed")
            sys.exit()
    else:
        print(gl_var_dict['srcFilename'] + " file not found")
        sys.exit()


def get_defroute_ipaddr(ip):
    return ([(s.connect((ip, 53)), s.getsockname()[0], s.close())
             for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]
             ][0][1])


def modify_configfile(targetfile, tag, value):
    if os.path.exists(targetfile):
        w_str = ''
        w_stat = False
        with open(targetfile, 'r') as f:
            for line in f.readlines():
                if re.search(tag, line):
                    line = re.sub(tag, value, line)
                    w_str += line
                    w_stat = True
                else:
                    w_str += line
            f.close()
        if w_stat:
            with open(targetfile, 'w') as f:
                f.write(w_str)
                f.close()


def check_curr_user(s):
    if getpass.getuser() != s:
        print('Current user not ' + s)
        sys.exit()
    elif getpass.getuser() == "root":
        print('root user is not allowed to install.')
        sys.exit()


def check_ip_parameter(s):
    compile_ip = re.compile(
        '^(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|[1-9])\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)\.(1\d{2}|2[0-4]\d|25[0-5]|[1-9]\d|\d)$'
    )
    if compile_ip.match(s):
        return True
    else:
        return False


def find_all_files(p):
    for root, dirs, files in os.walk(p):
        for f in files:
            yield f


def main():
    global serverIP
    if len(serverIP) != 0 and check_ip_parameter(serverIP):
        check_curr_user(gl_var_dict['targetUser'])
        try:
            hostIP = get_defroute_ipaddr(serverIP)
        except BaseException:
            print('Get host ip failed')
            sys.exit()
        if not os.path.exists(gl_var_dict['srcFilename']):
            for resActiveIP in gl_var_dict['resServers']:
                if diag_server_status(resActiveIP[0], resActiveIP[1]):
                    try:
                        download_package(resActiveIP[0], resActiveIP[1])
                    except IOError:
                        print('Write file error')
                        sys.exit()
                    else:
                        break
                else:
                    print('resource server unavailable, download failed')
        if os.path.exists(gl_var_dict['srcFilename']):
            decompress_packages()
            if os.path.exists(gl_var_dict['configFile']):
                modify_configfile(gl_var_dict['configFile'],
                                  '%change_hostname%', hostIP)
                modify_configfile(gl_var_dict['configFile'],
                                  '%change_serverip%', serverIP)
                modify_configfile(gl_var_dict['configFile'],
                                  '%change_basepath%',
                                  gl_var_dict['instDirName'])
            if os.path.exists(gl_var_dict['daemonScript']):
                modify_configfile(gl_var_dict['daemonScript'],
                                  '%change_basepath%',
                                  gl_var_dict['instDirName'])
            if os.path.exists(gl_var_dict['userParameterPath']):
                for f in find_all_files(gl_var_dict['userParameterPath']):
                    modify_configfile(
                        gl_var_dict['userParameterPath'] + '/' + f,
                        '%change_basepath%', gl_var_dict['instDirName'])
            add_cron_policy()
            print('Succeed.')
        else:
            print(gl_var_dict['srcFilename'] + ' file not found')
            sys.exit()
    else:
        print('Incorrect IP address format')
        help_info()
        sys.exit()


if __name__ == '__main__':
    os.chdir(sys.path[0])
    osinfo = get_os_version()
    if osinfo[0] == 'Linux':
        if osinfo[1].lower() == 'centos':
            if osinfo[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        elif osinfo[1].lower() == 'redhat':
            if osinfo[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        elif osinfo[1].lower() == 'suse':
            if osinfo[3].lower() == '64bit':
                main()
            else:
                print("Only for 64-bit operating systems")
                sys.exit()
        else:
            print(osinfo[1] + " Operating system is not supported")
            sys.exit()
    elif osinfo[0] == 'Windows':
        print(osinfo[0] + " Platform is not supported")
        sys.exit()
    else:
        print(osinfo[0] + " Platform is not supported")
        sys.exit()
