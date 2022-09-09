#!/usr/bin/env python
# -*- coding: utf8 -*-

import os
import sys
import json
import urllib2

alert_file = 'swift_proxy_dial.status'
token_file = 'token.dat'
alert_flag = False
renew_flag = False
token = ''
auth_url = 'http://1.1.1.1:5000'
swift_url = 'http://1.1.1.1:8888'
tenant_id = 'id'
tenant_name = 'str'
user = 'str'
key = 'str'
time_out = 3


def output_alert():
    global alert_flag, alert_file
    try:
        with open(alert_file, 'w+', 0x1A4) as f:
            if alert_flag:
                f.write('1')
            else:
                f.write('0')
            f.close()
    except Exception:
        print('输出拨测状态到文件失败')


def save_token():
    global token_file, token, alert_flag
    try:
        with open(token_file, 'w+', 0x180) as f:
            f.write(token)
            f.close
    except Exception:
        print('保存token到文件失败')
        try:
            os.remove(token_file)
        except Exception:
            print('移除' + token_file + '文件失败')
            alert_flag = True


def load_token():
    global token_file, token, renew_flag, alert_flag
    if os.path.exists(token_file):
        try:
            with open(token_file, 'r') as f:
                token = f.read().strip()
                f.close()
                if len(token) == 32:
                    return True
                else:
                    return False
        except Exception:
            print('读取token文件失败')
            alert_flag = True
            return False
    else:
        return False


def renew_token():
    global auth_url, token, tenant_name, user, key, time_out, alert_flag
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'python-keystoneclient'
    }
    payload = {
        "auth": {
            "tenantName": tenant_name,
            "passwordCredentials": {
                "username": user,
                "password": key
            }
        }
    }
    url = auth_url + '/v2.0/tokens'
    try:
        req = urllib2.Request(url=url,
                              data=json.dumps(payload),
                              headers=headers)
        res = urllib2.urlopen(req, timeout=time_out)
        if res.getcode() == 200:
            content = json.loads(res.read())
            token = content.get("access").get("token").get("id")
        else:
            print('获取token失败')
            alert_flag = True
            output_alert()
            sys.exit(1)
    except urllib2.URLError:
        print('keystone HTTP请求失败')
        alert_flag = True
        output_alert()
        sys.exit(1)


def get_status():
    global swift_url, token, tenant_id, time_out, renew_flag, alert_flag
    headers = {'Content-Type': 'application/json', 'X-Auth-Token': token}
    # payload = None
    url = swift_url + '/v1/' + tenant_id
    try:
        req = urllib2.Request(url=url, headers=headers)
        res = urllib2.urlopen(req, timeout=time_out)
        if res.getcode() == 200:
            print('拨测对象存储swift proxy服务状态正常')
        else:
            if renew_flag:
                print('拨测对象存储swift proxy服务状态异常')
                alert_flag = True
                output_alert()
                sys.exit(1)
            else:
                renew_flag = True
                renew_token()
                get_status()
    except urllib2.URLError:
        if renew_flag:
            print('swift proxy HTTP请求失败')
            alert_flag = True
            output_alert()
            sys.exit(1)
        else:
            renew_flag = True
            renew_token()
            get_status()


def main():
    global renew_flag
    if load_token():
        get_status()
    else:
        renew_flag = True
        renew_token()
        get_status()
    if renew_flag:
        save_token()
    output_alert()


if __name__ == "__main__":
    os.chdir(sys.path[0])
    main()
    sys.exit(0)
