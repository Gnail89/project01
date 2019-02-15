#!/usr/bin/env bash

f_rsyslog='/etc/rsyslog.conf'
f_remotelog='1.1.1.1'
f_logrotate='/etc/logrotate.d/syslog'

function restart_rsyslog(){
    systemctl status rsyslog
    if [ $? -eq 0 ]; then
        systemctl restart rsyslog
    fi
}

if [ -w ${f_rsyslog} ]; then
    cp ${f_rsyslog}{,.bak.$(date +%s)}
    # authpriv.*
    if [ $(grep -E '^authpriv.\*.*/var/log/secure' ${f_rsyslog} |wc -l) -eq 0 ]; then
        echo 'authpriv.*      /var/log/secure' >> ${f_rsyslog}
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
    # setup logrotate
    if [ -w ${f_logrotate} ]; then
        if [ $(grep -E '\/var\/log\/cron' ${f_logrotate} |wc -l) -eq 0 ]; then
            sed -i 's/\/var\/log\/messages/\/var\/log\/messages \/var\/log\/cron/g' ${f_logrotate}
        fi
        if [ $(grep -E '\/var\/log\/secure' ${f_logrotate} |wc -l) -eq 0 ]; then
            sed -i 's/\/var\/log\/messages/\/var\/log\/messages \/var\/log\/secure/g' ${f_logrotate}
        fi
        if [ $(grep -E '\/var\/log\/errors' ${f_logrotate} |wc -l) -eq 0 ]; then
            sed -i 's/\/var\/log\/messages/\/var\/log\/messages \/var\/log\/errors/g' ${f_logrotate}
        fi
    fi
    # reload service
    restart_rsyslog
fi
