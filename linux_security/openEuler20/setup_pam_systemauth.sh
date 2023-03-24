#!/usr/bin/env bash

f_pamsystemauth='/etc/pam.d/system-auth'
f_pampasswd='/etc/pam.d/passwd'

if [ -w ${f_pamsystemauth} ]; then
    cp ${f_pamsystemauth}{,.bak.$(date +%s)}
        # setup pam system-auth
        cat > ${f_pamsystemauth} << EOF
#%PAM-1.0
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        required      pam_faillock.so preauth audit deny=3 even_deny_root unlock_time=60
-auth        sufficient    pam_fprintd.so
auth        sufficient    pam_unix.so nullok try_first_pass
-auth        sufficient    pam_sss.so use_first_pass
auth        [default=die] pam_faillock.so authfail audit deny=3 even_deny_root unlock_time=60
auth        sufficient    pam_faillock.so authsucc audit deny=3 even_deny_root unlock_time=60
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        required      pam_deny.so

account     required      pam_unix.so
account     required      pam_faillock.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
-account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 minclass=2 minlen=8
password    sufficient    pam_unix.so shadow nullok try_first_pass use_authtok md5 shadow remember=5
-password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
-session     optional      pam_sss.so
EOF
    # option: fix environment /etc/pam.d/passwd
    if [ $(cat ${f_pampasswd} |grep '^password' |grep -E 'pam_cracklib.so|pam_unix.so|dcredit|ucredit|lcredit|ocredit|minlen|md5|remember' |wc -l) -ne 0 ]; then
        cp ${f_pampasswd}{,.bak.$(date +%s)}
        sed -i '/^password.*requisite.*pam_cracklib.so/d' ${f_pampasswd}
        sed -i '/^password.*pam_unix.so/d' ${f_pampasswd}
    fi
fi
