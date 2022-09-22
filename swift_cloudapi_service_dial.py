#!/usr/bin/env python
# -*- coding: utf8 -*-

import os
import sys
import json
import urllib2

alert_file = 'swift_cloudapi_dial.status'
alert_flag = False
renew_flag = False
token = None
cloudapi_url = 'https://1.1.1.1:8080'
swift_url = None
tenant_name = 'str'
user = 'str'
key = 'str'
container_name = 'str'
file_name = '1.txt'
time_out = 3


def output_alert():
    global alert_flag, alert_file
    try:
        with open(alert_file, 'w+') as f:
            if alert_flag:
                f.write('1')
            else:
                f.write('0')
            f.close()
    except Exception:
        print('输出拨测状态到文件失败')


def renew_token():
    global cloudapi_url, swift_url, token
    global tenant_name, user, key, time_out, alert_flag
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    payload = {
        "tenantName": tenant_name,
        "name": user,
        "password": key
    }
    url = cloudapi_url + '/openstack/identity/token/getnew'
    try:
        req = urllib2.Request(url=url,
                              data=json.dumps(payload),
                              headers=headers)
        res = urllib2.urlopen(req, timeout=time_out)
        if res.getcode() == 200:
            content = json.loads(res.read())
            if content.get("isSuccess") is True:
                token = content.get("tokenId")
                swift_url = content.get('swiftPublicURL')
            else:
                token = None
                swift_url = None
        else:
            print('调用getnew接口异常')
            alert_flag = True
            output_alert()
            sys.exit(1)
    except urllib2.URLError:
        print('获取token id失败')
        alert_flag = True
        output_alert()
        sys.exit(1)


def get_file():
    global cloudapi_url, swift_url, file_name, token
    global container_name, time_out, alert_flag, renew_flag
    headers = {
        'Content-Type': 'application/json'
    }
    payload = {
        "tokenId": token,
        "swiftPublicURL": swift_url,
        "name": file_name,
        "containerVO": {
            "name": container_name
        }
    }
    url = cloudapi_url + '/openstack/swift/object/download/inputStream'
    try:
        req = urllib2.Request(url=url,
                              data=json.dumps(payload),
                              headers=headers)
        res = urllib2.urlopen(req, timeout=time_out)
        if res.getcode() == 200:
            print('拨测对象存储cloudapi服务状态正常')
        else:
            if renew_flag:
                print('拨测对象存储cloudapi服务异常')
                alert_flag = True
                output_alert()
                sys.exit(1)
            else:
                renew_flag = True
                renew_token()
                get_file()
    except urllib2.URLError:
        if renew_flag:
            print('获取容器中的文件失败')
            alert_flag = True
            output_alert()
            sys.exit(1)
        else:
            renew_flag = True
            renew_token()
            get_file()


def main():
    global renew_flag, token
    renew_token()
    if token is None:
        renew_flag = True
        renew_token()
    get_file()
    output_alert()


if __name__ == "__main__":
    os.chdir(sys.path[0])
    main()
    sys.exit(0)
