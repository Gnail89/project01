#!/usr/bin/env bash
. ./setenv.sh

f_sshdcfg='/etc/ssh/sshd_config'
f_findfile=('.rhosts' 'hosts.equiv' '.netrc')
f_sshbanner='Authorized users only. All activity may be monitored and reported'
f_sshbannerfile='/etc/ssh_banner'

if [ -w ${f_sshdcfg} ]; then
    cp ${f_sshdcfg}{,.bak.$(date +%s)}
    # not permit root login
    if [ $(grep '^PermitRootLogin' ${f_sshdcfg} |wc -l) -eq 0 ]; then
        echo 'PermitRootLogin no' >> ${f_sshdcfg}
    elif [ $(grep '^PermitRootLogin.*no' ${f_sshdcfg} |wc -l) -eq 0 ]; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin no/g' ${f_sshdcfg}
    fi
    # Protocol 2
    if [ $(grep -i '^Protocol 2' ${f_sshdcfg} |wc -l) -eq 0 ]; then
        echo 'Protocol 2' >> ${f_sshdcfg}
    else
        sed -i -e '/^Protocol/d' -e '/^protocol/d' ${f_sshdcfg}
        echo 'Protocol 2' >> ${f_sshdcfg}
    fi
    # ssh banner
    if [ $(grep -E '^Banner' ${f_sshdcfg} |wc -l) -eq 0 ]; then
        echo "Banner ${f_sshbannerfile}" >> ${f_sshdcfg}
    else
        sed -i "s/^Banner.*/Banner \/etc\/ssh_banner/g" ${f_sshdcfg}
    fi
    echo "${f_sshbanner}" > ${f_sshbannerfile}
    [ -f ${f_sshbannerfile} ] && chmod 644 ${f_sshbannerfile}
    [ -f ${f_sshbannerfile} ] && chown bin:bin ${f_sshbannerfile}
fi

# find specific file
for bakfile in "${f_findfile[@]}"; do
    find /home/ -name "${bakfile}" -type f |xargs -i mv {}{,.bak.$(date +%s)}
done

# other options
if [ -d /home/smpint/ ] && [ ! -f /home/smpint/sshd_config ]; then
    cp -f ${f_sshdcfg} /home/smpint/sshd_config
    chown smpint:smpint /home/smpint/sshd_config
    chmod 644 /home/smpint/sshd_config
fi
