#!/usr/bin/env bash

f_ftpcfg='/etc/vsftpd.conf'
f_ftpusers='/etc/ftpusers'
f_ftpbanner='Authorized users only. All activity may be monitored and reported'
f_userlist=('root' 'daemon' 'bin' 'sys' 'adm' 'lp' 'uucp' 'nuucp' 'listen' 'nobody' 'noaccess' 'nobody4' 'anonymous')

if [ -w ${f_ftpusers} ]; then
    cp ${f_ftpusers}{,.bak.$(date +%s)}
    # setup users that are not allowed to login via ftp
    for userx in "${f_userlist[@]}"; do
        if id ${userx}; then
            if [ $(grep -w ^${userx} ${f_ftpusers} |wc -l) -eq 0 ]; then
                echo "${userx}" >> ${f_ftpusers}
            fi
        fi
    done
fi

if [ -w ${f_ftpcfg} ]; then
    cp ${f_ftpcfg}{,.bak.$(date +%s)}
    # setup disallow anonymous login
    if [ $(grep -E '^anonymous_enable' ${f_ftpcfg} |wc -l) -eq 0 ]; then
        echo 'anonymous_enable=NO' ${f_ftpcfg}
    elif [ $(grep -E '^anonymous_enable.*NO' ${f_ftpcfg} |wc -l) -eq 0 ]; then
        sed -i 's/^anonymous_enable.*/anonymous_enable=NO/g' ${f_ftpcfg}
    fi
    # setup ftp banner
    if [ $(grep -E '^ftpd_banner=' ${f_ftpcfg} |wc -l) -eq 0 ]; then
        echo "ftpd_banner=${f_ftpbanner}" >> ${f_ftpcfg}
    else
        sed -i "s/^ftpd_banner=.*/ftpd_banner=${f_ftpbanner}/g" ${f_ftpcfg}
    fi
fi

# other options
if [ -f ${f_ftpcfg} ] && [ -d /home/smpint/ ] && [ ! -f /home/smpint/vsftpd.conf ]; then
    cp -f ${f_ftpcfg} /home/smpint/vsftpd.conf
    chown smpint:smpint /home/smpint/vsftpd.conf
    chmod 644 /home/smpint/vsftpd.conf
fi
if [ -f ${f_ftpusers} ] && [ -d /home/smpint/ ] && [ ! -f /home/smpint/ftpusers ]; then
    cp -f ${f_ftpusers} /home/smpint/ftpusers
    chown smpint:smpint /home/smpint/ftpusers
    chmod 644 /home/smpint/ftpusers
fi
