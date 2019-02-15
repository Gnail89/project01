#!/usr/bin/env bash

f_securetty='/etc/securetty'

if [ -f ${f_securetty} ]; then
    sed -i "/^pts\//d" ${f_securetty}
fi
