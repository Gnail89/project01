#!/usr/bin/env bash

f_pamsu='/etc/pam.d/su'
f_pamcommonauth='/etc/pam.d/common-auth'
f_wheel_users=('aiuap' 'public' 'cloud')

if [ -w ${f_pamsu} ]; then
    cp ${f_pamsu}{,.bak.$(date +%s)}
    # setup pam su
    if [ $(grep -E '^auth.*required.*pam_wheel.so.*group=wheel.*' ${f_pamsu} |wc -l) -ne 1 ]; then
        cat > ${f_pamsu} << EOF
#%PAM-1.0
auth     sufficient     pam_rootok.so
auth     required       pam_wheel.so use_uid group=wheel
auth     include        common-auth
account  sufficient         pam_rootok.so
account  include        common-account
password include        common-password
session  include        common-session
session  optional       pam_xauth.so
EOF
        # option: fix environment /etc/pam.d/system-auth
        if [ $(grep -E '^auth.*required.*pam_wheel.so.*group=wheel.*' ${f_pamcommonauth} |wc -l) -ne 0 ]; then
            cp ${f_pamcommonauth}{,.bak.$(date +%s)}
            sed -i '/^auth.*required.*pam_wheel.so.*group=wheel.*/d' ${f_pamcommonauth}
        fi
        # option: add user to wheel group
        for userx in "${f_wheel_users[@]}"; do
            if id ${userx}; then
                groupmod -A ${userx} wheel
            fi
        done
    fi
fi
