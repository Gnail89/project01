#!/usr/bin/env bash

f_pamcommonpwd='/etc/pam.d/common-password'
f_pampasswd='/etc/pam.d/passwd'
f_pamopasswd='/etc/security/opasswd'

if [ -w ${f_pamcommonpwd} ]; then
    cp ${f_pamcommonpwd}{,.bak.$(date +%s)}
        # setup pam common-password
        cat > ${f_pamcommonpwd} << EOF
#%PAM-1.0
#
# This file is autogenerated by pam-config. All changes
# will be overwritten.
#
# Password-related modules common to all services
#
# This file is included from other service-specific PAM config files,
# and should contain a list of modules that define  the services to be
# used to change user passwords.
#
password        requisite       pam_cracklib.so retry=3 minlen=8 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 minclass=2
password        required        pam_unix.so     try_first_pass use_authtok nullok shadow md5 remember=5
EOF
    # fix environment opasswd
    if [ ! -f ${f_pamopasswd} ]; then
        touch ${f_pamopasswd}
        chown root:root ${f_pamopasswd}
        chmod 600 ${f_pamopasswd}
    elif [ -f ${f_pamopasswd} ]; then
        chown root:root ${f_pamopasswd}
        chmod 600 ${f_pamopasswd}
    fi
    # option: fix environment /etc/pam.d/passwd
    if [ $(cat ${f_pampasswd} |grep '^password' |grep -E 'pam_cracklib.so|pam_unix.so|dcredit|ucredit|lcredit|ocredit|minlen|md5|remember' |wc -l) -ne 0 ]; then
        cp ${f_pampasswd}{,.bak.$(date +%s)}
        sed -i '/^password.*requisite.*pam_cracklib.so/d' ${f_pampasswd}
        sed -i '/^password.*pam_unix.so/d' ${f_pampasswd}
    fi
fi
