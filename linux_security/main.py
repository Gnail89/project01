#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import platform
import commands


def Get_OS_Version():
    '''format: ('Linux', 'centos', '6.7', '64bit')'''
    return (platform.system(), platform.dist()[0], platform.dist()[1],
            platform.architecture()[0])


if __name__ == '__main__':
    red = '\033[1;31m'
    green = '\033[1;32m'
    yellow = '\033[1;33m'
    white = '\033[1;37m'
    reset = '\033[0m'
    os.chdir(sys.path[0])
    os_platform_info = Get_OS_Version()

    # scripts setup
    s_rhel6 = 'bash ./RHEL6/main.sh'
    s_rhel7 = 'bash ./RHEL7/main.sh'
    s_sles11 = 'bash ./SLES11/main.sh'
    s_sles12 = 'bash ./SLES12/main.sh'

    # select platform
    if os_platform_info[0].lower() == 'linux':
        # RHEL
        if (os_platform_info[1].lower() == 'centos'
                or os_platform_info[1].lower() == 'redhat'):
            if os_platform_info[2][:1] == '6':
                c_status = commands.getstatusoutput(s_rhel6)
                if c_status[0] != 0:
                    print(red + 'ERROR:\n' + c_status[1] + reset)
            elif os_platform_info[2][:1] == '7':
                c_status = commands.getstatusoutput(s_rhel7)
                if c_status[0] != 0:
                    print(red + 'ERROR:\n' + c_status[1] + reset)
        # SLES
        elif os_platform_info[1].lower() == 'suse':
            if os_platform_info[2] == '11':
                c_status = commands.getstatusoutput(s_sles11)
                if c_status[0] != 0:
                    print(red + 'ERROR:\n' + c_status[1] + reset)
            elif os_platform_info[2] == '12':
                c_status = commands.getstatusoutput(s_sles12)
                if c_status[0] != 0:
                    print(red + 'ERROR:\n' + c_status[1] + reset)
        else:
            print(red + 'Operating system is not supported.' + reset)
            sys.exit()
    else:
        print(red + 'Platform is not supported.' + reset)
        sys.exit()
