#!/usr/bin/env bash

f_logindefs='/etc/login.defs'

if [ -w ${f_logindefs} ]; then
    cp ${f_logindefs}{,.bak.$(date +%s)}
    # setup UMASK
    if [ $(grep -E '^UMASK' ${f_logindefs} |wc -l) -eq 0 ]; then
        sed -i '117i\UMASK      027' ${f_logindefs}
    elif [ $(grep -E '^UMASK.*0[2,7]7' ${f_logindefs} |wc -l) -eq 0 ]; then
        sed -i 's/^UMASK.*/UMASK      027/g' ${f_logindefs}
    fi
    # setup password min length
    if [ $(grep -E '^PASS_MIN_LEN' ${f_logindefs} |wc -l) -eq 0 ];then
        sed -i '/^PASS_MIN_DAYS/a\PASS_MIN_LEN    8' ${f_logindefs}
    else
        sed -i 's/^PASS_MIN_LEN.*/PASS_MIN_LEN    8/g' ${f_logindefs}
    fi
    # setup password max days
    if [ $(grep -E '^PASS_MAX_DAYS' ${f_logindefs} |wc -l) -eq 0 ]; then
        sed -i '131i\PASS_MAX_DAYS   90' ${f_logindefs}
    else
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/g' ${f_logindefs}
    fi
    # setup password warning days
    if [ $(grep -E '^PASS_WARN_AGE' ${f_logindefs} |wc -l) -eq 0 ]; then
        sed -i '134i\PASS_WARN_AGE   7' ${f_logindefs}
    else
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/g' ${f_logindefs}
    fi
fi
