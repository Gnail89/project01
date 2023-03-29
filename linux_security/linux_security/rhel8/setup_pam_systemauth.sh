#!/usr/bin/env bash

f_pamsystemauth='/etc/pam.d/system-auth'
f_pampasswd='/etc/pam.d/passwd'

if [ -w ${f_pamsystemauth} ]; then
    cp ${f_pamsystemauth}{,.bak.$(date +%s)}
        # setup pam system-auth
        cat > ${f_pamsystemauth} << EOF
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authselect is run.
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        required      pam_deny.so

account     required      pam_unix.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type= dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 minclass=2 minlen=8
password    sufficient    pam_unix.so try_first_pass use_authtok nullok md5 shadow remember=5
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
EOF
    # option: fix environment /etc/pam.d/passwd
    if [ $(cat ${f_pampasswd} |grep '^password' |grep -E 'pam_cracklib.so|pam_unix.so|dcredit|ucredit|lcredit|ocredit|minlen|md5|remember' |wc -l) -ne 0 ]; then
        cp ${f_pampasswd}{,.bak.$(date +%s)}
        sed -i '/^password.*requisite.*pam_cracklib.so/d' ${f_pampasswd}
        sed -i '/^password.*pam_unix.so/d' ${f_pampasswd}
    fi
fi
