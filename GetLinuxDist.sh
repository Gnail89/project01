#!/bin/bash

export PATH=/sbin:/bin:/usr/sbin:/usr/bin

osversion=""


function get_os_release(){
    local l_path="/etc/os-release"
    if [ x"${osversion}" == x"" ] && [ -r "${l_path}" ]; then
        osversion="$(egrep -i "^\<PRETTY_NAME\>=" "${l_path}" |sed -n 1p |sed -e "s/^\<PRETTY_NAME\>=//g" -e "s/\"//g")"
    fi
    unset l_path
}


function get_suse_release(){
    local l_path="/etc/SuSE-release"
    if [ x"${osversion}" == x"" ] && [ -r "${l_path}" ]; then
        osversion="$(egrep -i "\<SUSE\>" "${l_path}" |sed -n 1p |sed "s/$/ SP$(egrep -i "^\<PATCHLEVEL\>[[:space:]]*=[[:space:]]*" "${l_path}" |sed "s/^\<PATCHLEVEL\>[[:space:]]*=[[:space:]]*//g")/g")"
    fi
    unset l_path
}


function get_system_release(){
    local l_path="/etc/system-release"
    if [ x"${osversion}" == x"" ] && [ -r "${l_path}" ]; then
        osversion="$(sed -n 1p "${l_path}")"
    fi
    unset l_path
}


function get_redhat_release(){
    local l_path="/etc/redhat-release"
    if [ x"${osversion}" == x"" ] && [ -r "${l_path}" ]; then
        osversion="$(sed -n 1p "${l_path}")"
    fi
    unset l_path
}


function get_centos_release(){
    local l_path="/etc/centos-release"
    if [ x"${osversion}" == x"" ] && [ -r "${l_path}" ]; then
        osversion="$(sed -n 1p "${l_path}")"
    fi
    unset l_path
}


function main(){
    get_os_release
    get_suse_release
    get_system_release
    get_redhat_release
    get_centos_release
    if [ x"${osversion}" != x"" ]; then
        echo "${osversion}"
    else
        echo 'Unknown'
    fi
}


main
