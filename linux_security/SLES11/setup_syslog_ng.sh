#!/usr/bin/env bash

f_syslog='/etc/syslog-ng/syslog-ng.conf'
f_remotelog='1.1.1.1'
f_logrotate='/etc/logrotate.d/syslog'

function restart_syslog(){
    service syslog status
    if [ $? -eq 0 ]; then
        service syslog restart
    fi
}

if [ -w ${f_syslog} ]; then
    cp ${f_syslog}{,.bak.$(date +%s)}
    # authpriv.*
    if [ $(grep -E '^filter.*f_authpriv_info.*\{ facility\(authpriv\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'filter f_authpriv_info { facility(authpriv); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^destination.*authpriv_info.*\{ file\(\"\/var\/log\/authpriv_info\"\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'destination authpriv_info { file("/var/log/authpriv_info"); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^log.*\{ source\(src\)\; filter\(f_authpriv_info\)\; destination\(authpriv_info\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'log { source(src); filter(f_authpriv_info); destination(authpriv_info); };' >> ${f_syslog}
    fi
    # crontab logging
    if [ $(grep -E '^filter.*f_cron.*\{ facility\(cron\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'filter f_cron { facility(cron); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^destination.*cron.*\{ file\(\"\/var\/log\/cron\"\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'destination cron { file("/var/log/cron"); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^log.*\{ source\(src\)\; filter\(f_cron\)\; destination\(cron\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'log { source(src); filter(f_cron); destination(cron); };' >> ${f_syslog}
    fi
    # errors logging
    if [ $(grep -E '^filter.*f_errors.*\{ level\(err\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'filter f_errors { level(err); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^destination.*errors.*\{ file\(\"\/var\/log\/errors\"\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'destination errors { file("/var/log/errors"); };' >> ${f_syslog}
    fi
    if [ $(grep -E '^log.*\{ source\(src\)\; filter\(f_errors\)\; destination\(errors\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'log { source(src); filter(f_errors); destination(errors); };' >> ${f_syslog}
    fi
    # Remote Logging
    if [ $(grep -E '^filter.*f_somcprobe.*\{ level\(err\,crit\,alert\,emerg\) and not facility\(auth\) or level\(info\,notice\,warn\,err\,crit\,alert\,emerg\) and facility\(auth\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'filter f_somcprobe { level(info,notice,warn,err,crit,alert,emerg) and facility(auth) or level(notice) and facility(user); };' >> ${f_syslog}
    fi
    if [ $(grep -E "^destination.*d_somcprobe.*\{ udp\(\"${f_remotelog}\" port\(514\)" ${f_syslog} |wc -l) -eq 0 ]; then
        echo "destination d_somcprobe { udp(\"${f_remotelog}\" port(514) template(\"<\$PRI>ISMP_SUSE [\$FULLDATE] [\$HOST] [\$FACILITY.\$LEVEL] \$MSG\\n\"));};" >> ${f_syslog}
    fi
    if [ $(grep -E '^log.*\{ source\(src\)\; filter\(f_somcprobe\)\; destination\(d_somcprobe\)\; \}\;' ${f_syslog} |wc -l) -eq 0 ]; then
        echo 'log { source(src); filter(f_somcprobe); destination(d_somcprobe); };' >> ${f_syslog}
    fi
    # setup logrotate
    if [ -w ${f_logrotate} ]; then
        if [ $(grep -E '\/var\/log\/cron' ${f_logrotate} |wc -l) -eq 0 ]; then
            sed -i 's/\/var\/log\/messages/\/var\/log\/messages \/var\/log\/cron/g' ${f_logrotate}
        fi
        if [ $(grep -E '\/var\/log\/errors' ${f_logrotate} |wc -l) -eq 0 ]; then
            sed -i 's/\/var\/log\/messages/\/var\/log\/messages \/var\/log\/errors/g' ${f_logrotate}
        fi
    fi
    # reload service
    restart_syslog
fi
