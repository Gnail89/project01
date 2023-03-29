#!/usr/bin/env bash

f_pamsu='/etc/pam.d/su'
f_pamsystemauth='/etc/pam.d/system-auth'
f_wheel_users=('user')

if [ -w ${f_pamsu} ]; then
    cp ${f_pamsu}{,.bak.$(date +%s)}
    # setup pam su
    if [ $(grep -E '^auth.*required.*pam_wheel.so.*group=wheel.*' ${f_pamsu} |wc -l) -ne 1 ]; then
        cat > ${f_pamsu} << EOF
#######################################################################################
#
# Copyright (c) Huawei Technologies Co., Ltd. 2019. All rights reserved.
# security-tool licensed under the Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#     http://license.coscl.org.cn/MulanPSL
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR
# PURPOSE.
# See the Mulan PSL v2 for more details.
# Description: Configuration File for PAMified Services
#
#######################################################################################

#%PAM-1.0
auth            sufficient      pam_rootok.so
# Uncomment the following line to implicitly trust users in the "wheel" group.
#auth           sufficient      pam_wheel.so trust use_uid
# Uncomment the following line to require a user to be in the "wheel" group.
auth            required        pam_wheel.so use_uid group=wheel
auth            substack        system-auth
auth            include         postlogin
account         sufficient      pam_succeed_if.so uid = 0 use_uid quiet
account         include         system-auth
password        include         system-auth
session         include         system-auth
session         include         postlogin
session         optional        pam_xauth.so
EOF
        # option: fix environment /etc/pam.d/system-auth
        if [ $(grep -E '^auth.*required.*pam_wheel.so.*group=wheel.*' ${f_pamsystemauth} |wc -l) -ne 0 ]; then
            cp ${f_pamsystemauth}{,.bak.$(date +%s)}
            sed -i '/^auth.*required.*pam_wheel.so.*group=wheel.*/d' ${f_pamsystemauth}
        fi
        # option: add user to wheel group
        for userx in "${f_wheel_users[@]}"; do
            if id ${userx}; then
                gpasswd -a ${userx} wheel
            fi
        done
    fi
fi
