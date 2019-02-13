#!/usr/bin/env bash
. ./setenv.sh

f_service_list=('nfs' 'nfslock' 'nfs.lock' 'printer' 'tftp' 'lpd' 'ypbind' 'daytime' 'sendmail' 'ntalk' 'ident' 'bootps' 'kshell' 'klogin' 'lockd' 'nfsd' 'statd' 'mountd' 'lp' 'rpc' 'snmpdx' 'keyserv' 'nscd' 'volmgt' 'uucp' 'dmi' 'autoinstall')

for servicex in "${f_service_list[@]}"; do
    chkconfig ${servicex} off
done
