#!/usr/bin/env bash
export PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

user_list=('adm' 'lp' 'sync' 'shutdown' 'halt' 'news' 'uucp' 'operator' 'games' 'nobody' 'listen' 'gdm' 'webservd' 'nobody4' 'noaccess' 'rpm' 'smmsp' 'nfsnobody' 'daemon' 'bin')
user_noshell=('nobody')

for userx in "${user_list[@]}"; do
    if id ${userx}; then
        usermod -L ${userx}
    fi
done

for self in "${user_noshell[@]}"; do
    if id ${self}; then
        usermod -s /sbin/nologin ${self}
    fi
done

