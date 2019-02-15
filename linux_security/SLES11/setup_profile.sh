#!/usr/bin/env bash

f_profile='/etc/profile'
f_timeout='export TMOUT=180'
f_umask='umask 027'

if [ -w ${f_profile} ]; then
    cp ${f_profile}{,.bak.$(date +%s)}
    # Setup TMOUT
    if [ $(grep -E '^export.*TMOUT|^TMOUT=' ${f_profile} |wc -l) -eq 0 ]; then
        echo "${f_timeout}" >> ${f_profile}
    else
        sed -i -e '/^export.*TMOUT/d' -e '/^TMOUT=/d' ${f_profile}
        echo "${f_timeout}" >> ${f_profile}
    fi
    # Setup umask
    if [ $(grep -E '^umask.*027' ${f_profile} |wc -l) -eq 0 ]; then
        echo "${f_umask}" >> ${f_profile}
    fi
fi
