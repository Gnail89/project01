#!/usr/bin/env bash
. ./setenv.sh
basepath=$(cd `dirname $0`;pwd)

. ${basepath}/../common/passwd_lock.sh
. ${basepath}/../common/user_lock.sh
. ${basepath}/setup_logindefs.sh
. ${basepath}/setup_pam_commonpassword.sh
. ${basepath}/setup_pam_su.sh
. ${basepath}/setup_profile.sh
. ${basepath}/setup_securetty.sh
. ${basepath}/setup_sshd.sh
. ${basepath}/setup_sysbanner.sh
. ${basepath}/setup_syslog_ng.sh
. ${basepath}/setup_vsftpd.sh
. ${basepath}/disable_service.sh
. ${basepath}/disable_telnetserver.sh
. ${basepath}/file_permission.sh
