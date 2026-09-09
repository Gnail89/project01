#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# swift_pull_objects.py — 健壮的 Swift 2.2 (OpenStack Object Storage) 对象名列表拉取脚本。
#
# 由 OpenSpec change `convert-swift-puller-to-python` 实现，为
# `swift_api_pull_objects.sh` 的纯 Python 3 标准库等价替代（无第三方依赖）。
# 行为契约见 openspec/specs/swift-object-pull/spec.md。
#
# 用法:
#   swift_pull_objects.py <container_list_file>
#
# 容器列表文件: 每行一个容器名; 空行与 '#' 注释行被忽略; 重复容器名被去重。
#
# 输出（每容器两个文件，位于当前工作目录）:
#   <container>.list   — 每行一个纯对象名（仅成功解析后追加）
#   <container>.marker — 仅保存当前成功翻页后的 marker 值（断点续传）
#
# 需要环境变量（必需，缺一即报错退出）:
#   SWIFT_TENANT_NAME  SWIFT_USER_NAME  SWIFT_PASS  SWIFT_ACCOUNT_ID  SWIFT_AUTH_URL
# 可选环境变量:
#   SWIFT_STORAGE_URL     对象存储 URL; 缺省时自动从认证响应的 serviceCatalog 提取
#   SWIFT_LIMIT           每页对象数（默认 10000; 非数字或 >10000 均钳制到 10000）
#   SWIFT_RETRIES         网络/非认证类错误固定重试次数（默认 3，按页重置）
#   SWIFT_AUTH_RETRIES    连续凭证认证失败上限（默认 3，容器级累计）
#   SWIFT_PAGE_AUTH_RETRIES  单页 401/403 授权拒绝重认证上限（默认 3，按页重置）
#   SWIFT_TIMEOUT         连接/读取超时秒数（默认 60）
#
# 退出码:
#   0 = 全部容器成功（含容器列表为空/全注释空行）
#   1 = 至少一个容器失败 / 缺失必需环境变量 / 容器列表文件不存在
#   2 = 用法错误（参数数不等于 1）
#
# 说明: SWIFT_LIMIT 过大时单页响应体可达数 MB（全部读入内存），
#       需内存敏感场景可调小 SWIFT_LIMIT 缓解。

import http.client
import json
import os
import socket
import sys
import time
from urllib.parse import quote, urlsplit

CONTAINER_LISTING_LIMIT = 10000  # Swift 2.2 constraints.CONTAINER_LISTING_LIMIT

REQUIRED_ENV_VARS = (
    "SWIFT_TENANT_NAME",
    "SWIFT_USER_NAME",
    "SWIFT_PASS",
    "SWIFT_ACCOUNT_ID",
    "SWIFT_AUTH_URL",
)


def log(message):
    print(message, file=sys.stderr, flush=True)


def to_int(value, default):
    """数字字符串转 int，非数字返回 default（对位 bash 非数字钳制）。"""
    try:
        n = int(value)
    except (TypeError, ValueError):
        return default
    return n


def load_config():
    """读取环境变量并做校验与钳制。校验失败返回值首元素为 False。"""
    missing = [v for v in REQUIRED_ENV_VARS if not os.environ.get(v)]
    if missing:
        for v in missing:
            log("错误: 缺少必需环境变量 %s" % v)
        log("为避免失败，所有必需环境变量必须非空：%s" % " ".join(REQUIRED_ENV_VARS))
        return None

    limit = to_int(os.environ.get("SWIFT_LIMIT"), CONTAINER_LISTING_LIMIT)
    if limit < 0 or limit > CONTAINER_LISTING_LIMIT:
        limit = CONTAINER_LISTING_LIMIT

    return {
        "tenant_name": os.environ.get("SWIFT_TENANT_NAME"),
        "user_name": os.environ.get("SWIFT_USER_NAME"),
        "password": os.environ.get("SWIFT_PASS"),
        "account_id": os.environ.get("SWIFT_ACCOUNT_ID"),
        "auth_url": os.environ.get("SWIFT_AUTH_URL"),
        "storage_url": os.environ.get("SWIFT_STORAGE_URL") or None,
        "limit": limit,
        "retries": to_int(os.environ.get("SWIFT_RETRIES"), 3),
        "auth_retries": to_int(os.environ.get("SWIFT_AUTH_RETRIES"), 3),
        "page_auth_retries": to_int(os.environ.get("SWIFT_PAGE_AUTH_RETRIES"), 3),
        "timeout": to_int(os.environ.get("SWIFT_TIMEOUT"), 60),
    }


def list_containers(path):
    """读取容器列表：跳过空行与 '#' 注释行，单行去重（顺序保持）。"""
    if not os.path.isfile(path):
        log("错误: 容器列表文件不存在: %s" % path)
        return False, []
    seen = []
    names = []
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            name = raw.rstrip("\n").rstrip("\r")
            if not name or name.startswith("#"):
                continue
            if name not in seen:
                seen.append(name)
                names.append(name)
    return True, names


def request(cfg, method, url, headers=None, body=None):
    """按 scheme 选择 HTTP/HTTPS 连接发请求，返回 (status:int, body:str)。

    任何状态码都正常返回；网络类异常经分类后由调用方重试。
    返回 ('NET_ERROR', None) 表示网络错误。
    """
    scheme = "https" if url.startswith("https") else "http"
    parts = urlsplit(url)
    host = parts.hostname or ""
    port = parts.port
    path = parts.path or "/"
    if parts.query:
        path = path + "?" + parts.query

    headers = dict(headers or {})
    if "Host" not in headers:
        if port:
            headers["Host"] = "%s:%s" % (host, port)
        else:
            headers["Host"] = host

    try:
        if scheme == "https":
            conn = http.client.HTTPSConnection(host, port=port, timeout=cfg["timeout"])
        else:
            conn = http.client.HTTPConnection(host, port=port, timeout=cfg["timeout"])
        try:
            conn.request(method, path, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            status = resp.status
            return status, data.decode("utf-8")
        finally:
            conn.close()
    except (socket.timeout, http.client.HTTPException, OSError):
        return "NET_ERROR", None


def auth(cfg, storage_url):
    """Keystone v2.0 token 认证。成功返回 (token, storage_url)；失败返回 (None, None)。"""
    payload = json.dumps({
        "auth": {
            "tenantName": cfg["tenant_name"],
            "passwordCredentials": {
                "username": cfg["user_name"],
                "password": cfg["password"],
            },
        }
    })
    status, body = request(
        cfg,
        "POST",
        cfg["auth_url"],
        headers={"Content-Type": "application/json"},
        body=payload,
    )
    if status == "NET_ERROR" or status not in (200, 201):
        log("认证失败（status=%s）" % str(status))
        return None, None
    try:
        data = json.loads(body)
    except ValueError:
        log("认证失败（响应 JSON 解析失败）")
        return None, None
    access = data.get("access", {}) if isinstance(data, dict) else {}
    token = access.get("token", {}).get("id") or ""
    if not token:
        log("认证失败（未解析到 token）")
        return None, None
    if storage_url is None:
        for svc in access.get("serviceCatalog", []) or []:
            if not isinstance(svc, dict) or svc.get("type") != "object-store":
                continue
            for ep in svc.get("endpoints", []) or []:
                if not isinstance(ep, dict):
                    continue
                su = ep.get("publicURL") or ep.get("internalURL")
                if su:
                    storage_url = su
                    break
            if storage_url:
                break
    if not storage_url:
        log("认证失败（未确定 object-store storageURL）")
        return None, None
    return token, storage_url


def parse_objects(body):
    """解析 format=json 对象列表，返回名字列表；失败返回 None（绝不当作空列表）。"""
    try:
        data = json.loads(body)
    except ValueError:
        return None
    if not isinstance(data, list):
        return None
    names = []
    for entry in data:
        if isinstance(entry, dict) and "name" in entry:
            names.append(entry["name"])
    return names


def pull_container(cfg, name):
    """拉取单个容器。返回 0 成功 | 1 重试耗尽 | 2 认证永久失败 | 3 单页授权拒绝 | 4 404。"""
    list_file = name + ".list"
    marker_file = name + ".marker"

    log("开始处理容器: %s" % name)

    auth_failures = 0
    storage_url = cfg["storage_url"]
    token = None

    while True:
        token, storage_url = auth(cfg, storage_url)
        if token is not None:
            auth_failures = 0
            break
        auth_failures += 1
        if auth_failures >= cfg["auth_retries"]:
            log("容器 %s: 连续认证失败 %d 次达上限，跳过该容器。" % (name, auth_failures))
            return 2
        time.sleep(1)

    marker = ""
    if os.path.isfile(marker_file) and os.path.getsize(marker_file) > 0:
        with open(marker_file, "r", encoding="utf-8") as fh:
            marker = fh.read()

    while True:
        page_url = "%s/%s?format=json&limit=%d" % (storage_url.rstrip("/"), name, cfg["limit"])
        if marker:
            page_url = page_url + "&marker=" + quote(marker, safe="")

        hand = 0        # SWIFT_RETRIES 硬失败计数，每页重置
        page_401 = 0    # SWIFT_PAGE_AUTH_RETRIES 单页授权拒绝计数，每页重置

        while True:
            status, body = request(
                cfg,
                "GET",
                page_url,
                headers={"X-Auth-Token": token},
            )

            if status == "NET_ERROR":
                if hand >= cfg["retries"]:
                    log("容器 %s: 网络失败重试耗尽，跳过该容器。" % name)
                    return 1
                hand += 1
                time.sleep(1)
                continue

            if status == 200:
                names = parse_objects(body)
                if names is None:
                    if hand >= cfg["retries"]:
                        log("容器 %s: HTTP 200 但 JSON 解析失败，重试耗尽，跳过该容器。" % name)
                        return 1
                    hand += 1
                    time.sleep(1)
                    continue
                count = len(names)
                if count > 0:
                    with open(list_file, "a", encoding="utf-8") as fh:
                        for n in names:
                            fh.write(n + "\n")
                    marker = names[-1]
                    with open(marker_file, "w", encoding="utf-8") as fh:
                        fh.write(marker)
                if count < cfg["limit"]:
                    log("容器 %s: 拉取完成（末页 %d 个对象，共翻页结束）。" % (name, count))
                    return 0
                break

            if status == 204:
                log("容器 %s: 收到 204，视为正常到底。" % name)
                return 0

            if status in (401, 403):
                page_401 += 1
                if page_401 >= cfg["page_auth_retries"]:
                    log("容器 %s: 本页连续收到 %d 达 %d 次（授权被永久拒绝），该页失败，跳过容器。"
                        % (name, status, cfg["page_auth_retries"]))
                    return 3
                token, storage_url = auth(cfg, storage_url)
                if token is not None:
                    auth_failures = 0
                else:
                    auth_failures += 1
                    if auth_failures >= cfg["auth_retries"]:
                        log("容器 %s: 重新认证连续失败达 %d 次，视为认证永久失败，跳过容器。"
                            % (name, cfg["auth_retries"]))
                        return 2
                time.sleep(1)
                continue

            if status == 404:
                log("容器 %s: 收到 404（容器/资源缺失），跳过该容器。" % name)
                return 4

            if hand >= cfg["retries"]:
                log("容器 %s: HTTP %d 重试耗尽，跳过该容器。" % (name, status))
                return 1
            hand += 1
            time.sleep(1)


def main(argv):
    if len(argv) != 1:
        print("用法: %s <container_list_file>" % sys.argv[0], file=sys.stderr)
        return 2

    cfg = load_config()
    if cfg is None:
        return 1

    ok, containers = list_containers(argv[0])
    if not ok:
        return 1

    if not containers:
        log("容器列表为空或全部为注释/空行，未处理任何容器。")
        return 0

    had_failure = False
    for name in containers:
        try:
            rc = pull_container(cfg, name)
        except Exception as exc:  # 外层保护：单容器异常不中断后续容器
            log("容器 %s 发生未预期异常（%s），跳过。" % (name, exc))
            had_failure = True
            continue
        if rc != 0:
            log("容器 %s 失败（code=%d）。" % (name, rc))
            had_failure = True

    if had_failure:
        log("存在容器处理失败，返回非零退出码。")
        return 1
    log("全部容器处理完成。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
