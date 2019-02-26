#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import requests
import json
import time

try:
    hostname = sys.argv[1]
    host_ip = sys.argv[2]
    host_group_id = sys.argv[3]
    template_id = sys.argv[4]
    zabbix_username = sys.argv[5]
    zabbix_password = sys.argv[6]
    url = sys.argv[7]
except BaseException:
    print('[hostname] [host_ip] [host_group_id] [template_id]' +
          ' [zabbix_username] [zabbix_password] [auth_url]')
    sys.exit()

headers = {'content-type': 'application/json'}


def get_auth_key():
    payload = {
        "jsonrpc": "2.0",
        "method": "user.login",
        "params": {
            "user": zabbix_username,
            "password": zabbix_password
        },
        "id": 1,
    }
    r = requests.post(url, data=json.dumps(payload), headers=headers)
    if r.status_code != 200:
        print('problem - get key')
        print(r.status_code)
        print(r.text)
        sys.exit()
    else:
        result = r.json()
        auth_key = result['result']
        return auth_key


def create_host(auth_key):
    payload = {
        "jsonrpc": "2.0",
        "method": "host.create",
        "params": {
            "host":
            hostname,
            "interfaces": [{
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": host_ip,
                "dns": "",
                "port": "10050"
            }],
            "groups": [{
                "groupid": host_group_id
            }],
            "templates": [{
                "templateid": template_id
            }]
        },
        "auth": auth_key,
        "id": 1
    }
    r = requests.post(url, data=json.dumps(payload), headers=headers)
    if r.status_code != 200:
        print('problem - host create')
        sys.exit()
    else:
        try:
            result = r.json()['result']
            host_id = result['hostids'][0]
            return host_id
        except BaseException:
            result = r.json()['error']
            print('problem - host create response')
            print(result)
            sys.exit()


def set_maintenance(auth_key, host_id):
    active_since = int(time.time())
    active_till = int(time.time() + 600)
    payload = {
        "jsonrpc": "2.0",
        "method": "maintenance.create",
        "params": {
            "name":
            'new server initialization period_' + str(active_till),
            "active_since":
            active_since,
            "active_till":
            active_till,
            "hostids": [host_id],
            "timeperiods": [{
                "timeperiod_type": 0,
                "start_time": active_since,
                "period": 1800
            }]
        },
        "auth": auth_key,
        "id": 1
    }
    r = requests.post(url, data=json.dumps(payload), headers=headers)
    if r.status_code != 200:
        print('problem - set maintenance')
        sys.exit()
    else:
        try:
            result = r.json()['result']
            print(result)
        except BaseException:
            result = r.json()['error']
            print('problem - set maintenance response')
            print(result)
            sys.exit()


if __name__ == "__main__":
    os.chdir(sys.path[0])
    auth_key = get_auth_key()
    host_id = create_host(auth_key)
    set_maintenance(auth_key, host_id)
