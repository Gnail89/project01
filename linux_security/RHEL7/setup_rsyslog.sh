#!/usr/bin/env bash

f_rsyslog='/etc/rsyslog.conf'
f_remotelog='1.1.1.1'

function restart_rsyslog(){
    service rsyslog status
    if [ $? -eq 0 ]; then
        service rsyslog restart
    fi
}

if [ -w ${f_rsyslog} ]; then
    cp ${f_rsyslog}{,.bak.$(date +%s)}
    # authpriv.*
    if [ $(grep -E '^authpriv.\*.*/var/log/secure' ${f_rsyslog} |wc -l) -eq 0 ]; then
        echo 'authpriv.*      /var/log/secure' >> ${f_rsyslog}
    fi
    # authpriv.info
    if [ $(grep -E '^authpriv.info.*/var/log/authpriv_info' ${f_rsyslog} |wc -l) -eq 0 ]; then
        echo 'authpriv.info      /var/log/authpriv_info' >> ${f_rsyslog}
    fi
    # crontab logging
    if [ $(grep -E '^cron.\*.*/var/log/cron' ${f_rsyslog} |wc -l) -eq 0 ];then
        echo 'cron.*      /var/log/cron' >> ${f_rsyslog}
    fi
    # errors logging
    if [ $(grep -E '^\*.err.*/var/log/errors' ${f_rsyslog} |wc -l) -eq 0 ];then
        echo '*.err      /var/log/errors' >> ${f_rsyslog}
    fi
    # Remote Logging
    if [ $(grep -E "^\*.\*.*@*${f_remotelog}" ${f_rsyslog} |wc -l) -eq 0 ]; then
        echo "*.*      @${f_remotelog}" >> ${f_rsyslog}
    fi
    # reload service
    restart_rsyslog
fi
