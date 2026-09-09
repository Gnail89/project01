#!/usr/bin/env bash
#
# swift_api_pull_objects.sh — 健壮的 Swift 2.2 (OpenStack Object Storage) 对象名列表拉取脚本。
#
# 依据 OpenSpec change `improve-swift-api-pull-robustness` 的规格与设计实现。
#
# 用法:
#   swift_api_pull_objects.sh <container_list_file>
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
#   SWIFT_LIMIT           每页对象数（默认 10000，钳制到服务端上限）
#   SWIFT_RETRIES         网络/非认证类错误固定重试次数（默认 3）
#   SWIFT_AUTH_RETRIES    连续凭证认证失败上限（默认 3）
#   SWIFT_PAGE_AUTH_RETRIES  单页 401/403 授权拒绝重认证上限（默认 3）
#   SWIFT_TIMEOUT         curl 超时秒数（默认 60）
#
# 退出码: 0 = 全部容器成功; 非 0 = 至少一个容器失败。

set -euo pipefail

# ---------------------------------------------------------------------------
# 配置读取与校验（D5 / spec: 配置由环境变量提供并在启动时校验）
# ---------------------------------------------------------------------------

PYTHON_BIN="${PYTHON_BIN:-}"
REQ_ENV_VARS=(SWIFT_TENANT_NAME SWIFT_USER_NAME SWIFT_PASS SWIFT_ACCOUNT_ID SWIFT_AUTH_URL)

CONTAINER_LISTING_LIMIT=10000   # Swift 2.2 constraints.CONTAINER_LISTING_LIMIT

SWIFT_LIMIT="${SWIFT_LIMIT:-10000}"
SWIFT_RETRIES="${SWIFT_RETRIES:-3}"
SWIFT_AUTH_RETRIES="${SWIFT_AUTH_RETRIES:-3}"
SWIFT_PAGE_AUTH_RETRIES="${SWIFT_PAGE_AUTH_RETRIES:-3}"
SWIFT_TIMEOUT="${SWIFT_TIMEOUT:-60}"

# 钳制 limit 到服务端上限，避免收到 HTTP 400（spec: limit 超过上限被钳制）。
if ! [[ "$SWIFT_LIMIT" =~ ^[0-9]+$ ]] || (( SWIFT_LIMIT > CONTAINER_LISTING_LIMIT )); then
    SWIFT_LIMIT=$CONTAINER_LISTING_LIMIT
fi

log() { printf '%s\n' "$*" >&2; }

resolve_python() {
    if [[ -n "$PYTHON_BIN" ]] && command -v "$PYTHON_BIN" >/dev/null 2>&1; then
        printf '%s' "$PYTHON_BIN"; return
    fi
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' python3; return
    fi
    if command -v python >/dev/null 2>&1; then
        printf '%s' python; return
    fi
    return 1
}

validate_env() {
    local missing=0 v
    for v in "${REQ_ENV_VARS[@]}"; do
        if [[ -z "${!v:-}" ]]; then
            log "错误: 缺少必需环境变量 $v"
            missing=1
        fi
    done
    if (( missing )); then
        log "为避免失败，所有必需环境变量必须非空：${REQ_ENV_VARS[*]}"
        return 1
    fi
    if ! PYTHON_BIN="$(resolve_python)"; then
        log "错误: 找不到 python/python3，本脚本依赖其解析认证响应与 JSON 对象列表。"
        return 1
    fi
    return 0
}

# 读取容器列表文件：跳过空行与 '#' 注释行，容器名单行去重，逐个输出。
list_containers() {
    local file="$1" name dup x
    # 哨兵元素使数组永非空：规避 set -u 下空数组展开 (${arr[@]} / ${arr[*]})
    # 在 bash<4.4（CentOS 7 的 bash 4.2）报 unbound variable 的问题。
    # 哨兵值不可能与真实容器名相等（真实名非空且不可能是此哨兵），不影响去重。
    local -a seen=("__SENTINEL__")
    [[ -f "$file" ]] || { log "错误: 容器列表文件不存在: $file"; return 1; }
    while IFS= read -r name || [[ -n "$name" ]]; do
        name="${name%%$'\r'}"
        [[ -z "$name" || "$name" == \#* ]] && continue
        # 逐元素比较去重（哨兵保证 ${seen[@]} 非空安全展开；逐元素避免
        # 字符串包含法对含空格容器名 a b 中 b 的误判去重）。
        dup=0
        for x in "${seen[@]}"; do
            [[ "$x" == "$name" ]] && { dup=1; break; }
        done
        (( dup )) && continue
        printf '%s\n' "$name"
        seen+=("$name")
    done < "$file"
}

# ---------------------------------------------------------------------------
# 认证（D4 / 2.1）: Keystone v2.0 token。成功设 AUTH_TOKEN/STORAGE_URL 并返回 0。
# ---------------------------------------------------------------------------

AUTH_TOKEN=""
STORAGE_URL="${SWIFT_STORAGE_URL:-}"

auth() {
    local body_tmp code rc=0
    local payload
    payload="{\"auth\":{\"tenantName\":\"$SWIFT_TENANT_NAME\",\"passwordCredentials\":{\"username\":\"$SWIFT_USER_NAME\",\"password\":\"$SWIFT_PASS\"}}}"

    body_tmp="$(mktemp)"
    code="$(curl -sS --max-time "$SWIFT_TIMEOUT" -o "$body_tmp" -w "%{http_code}" \
        -H 'Content-Type: application/json' \
        -d "$payload" \
        "$SWIFT_AUTH_URL")" || rc=$?

    # 解析认证响应。
    local auth_out
    auth_out="$(STORAGE_URL="$STORAGE_URL" "$PYTHON_BIN" - "$body_tmp" "$code" <<'PYEOF' 2>/dev/null || true
from __future__ import print_function
import json, os, sys
# py2 stdout defaults to ASCII; printing non-ASCII content raises
# UnicodeEncodeError. Reset default encoding to UTF-8 (skipped on py3).
# Affects this subprocess only.
if sys.version_info[0] < 3:
    reload(sys)
    sys.setdefaultencoding("utf-8")
storage = os.environ.get("STORAGE_URL", "") or None
try:
    if sys.argv[2] not in ("200", "201"):
        sys.exit(1)
    with open(sys.argv[1]) as f:
        d = json.load(f)
    token = d.get("access", {}).get("token", {}).get("id", "")
    if not token:
        sys.exit(1)
    print("TOKEN=" + token)
    if storage is None:
        for svc in d.get("access", {}).get("serviceCatalog", []):
            if svc.get("type") == "object-store":
                for ep in svc.get("endpoints", []):
                    su = ep.get("publicURL") or ep.get("internalURL")
                    if su:
                        storage = su
                        break
                if storage:
                    break
    if storage:
        print("STORAGE=" + storage)
except Exception:
    sys.exit(1)
PYEOF
)"
    rm -f "$body_tmp"

    if (( rc != 0 )) || [[ $auth_out != TOKEN=* ]]; then
        log "认证失败（status=$code rc=$rc）"
        return 1
    fi

    local k v
    AUTH_TOKEN=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        case "$line" in
            TOKEN=*) AUTH_TOKEN="${line#TOKEN=}" ;;
            STORAGE=*) if [[ -z "${SWIFT_STORAGE_URL:-}" ]]; then STORAGE_URL="${line#STORAGE=}"; fi ;;
        esac
    done <<< "$auth_out"

    if [[ -z "$AUTH_TOKEN" ]]; then
        log "认证成功但未解析到 token"
        return 1
    fi
    if [[ -z "$STORAGE_URL" ]]; then
        log "认证成功但未能确定 object-store storageURL（未设 SWIFT_STORAGE_URL 且 serviceCatalog 不含 object-store）"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# 请求与解析（D2 / D4 / 2.2 / 3.1）
# ---------------------------------------------------------------------------

# fetch_raw: 发一次 GET 写入临时文件，stdout 输出 HTTP 状态码；curl 出错返回非 0。
fetch_raw() {
    local url="$1" out="$2"
    curl -sS --max-time "$SWIFT_TIMEOUT" -o "$out" -w "%{http_code}" \
        -H "X-Auth-Token: $AUTH_TOKEN" \
        "$url"
}

# parse_objects: 解析 format=json 临时文件，将对象名每行一个写 stdout，返回 0。
#   解析失败返回 1，且不输出部分结果（绝不静默当作空列表到底）。
parse_objects() {
    local tmp="$1"
    "$PYTHON_BIN" - "$tmp" <<'PYEOF'
from __future__ import print_function
import json, sys
# py2 stdout defaults to locale (ASCII) encoding; printing non-ASCII object
# names raises UnicodeEncodeError. Reset default encoding to UTF-8 (skipped on
# py3). Affects this subprocess only.
if sys.version_info[0] < 3:
    reload(sys)
    sys.setdefaultencoding("utf-8")
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    print("ERR_PARSE", file=sys.stderr)
    sys.exit(1)
if not isinstance(data, list):
    print("ERR_STRUCT", file=sys.stderr)
    sys.exit(1)
for entry in data:
    if isinstance(entry, dict) and "name" in entry:
        print(entry["name"])
sys.exit(0)
PYEOF
}

# urlencode: 对 marker 做字节级百分号编码（避免特殊/非 UTF-8 字符触发 400）。
# 双兼容 py2.7.5 / py3：py2 用 urllib.quote，py3 用 urllib.parse.quote，均按 UTF-8 编码。
urlencode() {
    "$PYTHON_BIN" - "$1" <<'PYEOF'
from __future__ import print_function
import sys
try:
    from urllib.parse import quote
except ImportError:
    from urllib import quote
arg = sys.argv[1]
# py2 argv are byte strings(str); py3 are unicode(str). Only encode unicode
# to UTF-8 bytes; byte strings(py2) quoted as-is (already encoded bytes), so
# avoid UnicodeDecodeError when calling encode on py2 str (e.g. CJK marker).
if isinstance(arg, type(u"")):
    arg = arg.encode("utf-8")
print(quote(arg, safe=""))
PYEOF
}

# is_end: 仅在“解析成功”的前提下判定到底：对象数 < limit 即到底。
is_end() {
    (( $1 < $2 ))
}

# ---------------------------------------------------------------------------
# 单容器拉取（D1..D4 / 2.3 / 3.x / 4.x）
# 返回码: 0 成功 | 1 重试耗尽 | 2 认证永久失败 | 3 单页授权拒绝 | 4 404 缺失
# ---------------------------------------------------------------------------
pull_container() {
    local name="$1"
    local list_file="${name}.list"
    local marker_file="${name}.marker"
    local auth_failures=0

    log "开始处理容器: $name"

    # 首次认证（含连续失败重试，达 SWIFT_AUTH_RETRIES 视为永久失败）。
    while :; do
        if auth; then
            auth_failures=0
            break
        fi
        ((auth_failures++))
        if (( auth_failures >= SWIFT_AUTH_RETRIES )); then
            log "容器 $name: 连续认证失败 ${auth_failures} 次达上限，跳过该容器。"
            return 2
        fi
        sleep 1
    done

    # 断点续传起点 marker。
    local marker=""
    if [[ -s "$marker_file" ]]; then
        marker="$(< "$marker_file")"
    fi

    local page_url enc tmp count code page_rc page_401 hand rc
    local objlist

    while :; do
        page_url="${STORAGE_URL}/${name}?format=json&limit=${SWIFT_LIMIT}"
        if [[ -n "$marker" ]]; then
            enc="$(urlencode "$marker")"
            page_url="${page_url}&marker=${enc}"
        fi

        tmp="$(mktemp)"
        hand=0
        page_401=0

        # 内层状态分发 + 重试循环。
        while :; do
            page_rc=0
            code="$(fetch_raw "$page_url" "$tmp")" || page_rc=$?

            if (( page_rc != 0 )); then
                # curl 非零退出（超时/连接失败）→ 固定次数重试（SWIFT_RETRIES）。
                if (( hand >= SWIFT_RETRIES )); then
                    log "容器 $name: curl 失败（rc=$page_rc）重试耗尽，跳过该容器。"
                    rm -f "$tmp"; return 1
                fi
                ((hand++)); sleep 1
                continue
            fi

            case "$code" in
                200)
                    objlist="$(parse_objects "$tmp")" || {
                        # HTTP 200 但 JSON 解析失败 → 该页失败，进入重试，绝不判到底。
                        if (( hand >= SWIFT_RETRIES )); then
                            log "容器 $name: HTTP 200 但 JSON 解析失败，重试耗尽，跳过该容器。"
                            rm -f "$tmp"; return 1
                        fi
                        ((hand++)); sleep 1
                        continue
                    }
                    count="$(printf '%s' "$objlist" | grep -c . || true)"
                    # 写输出与状态：先 .list，后 .marker（宁可重复不遗漏）。
                    if (( count > 0 )); then
                        printf '%s\n' "$objlist" >> "$list_file"
                        marker="$(printf '%s\n' "$objlist" | tail -n 1)"
                        printf '%s' "$marker" > "$marker_file"
                    fi
                    if is_end "$count" "$SWIFT_LIMIT"; then
                        rm -f "$tmp"
                        log "容器 $name: 拉取完成（末页 $count 个对象，共翻页结束）。"
                        return 0
                    fi
                    # count == limit → marker 已更新为最后一个对象名，继续下一页。
                    rm -f "$tmp"
                    break
                    ;;
                204)
                    # 纯文本空列表到底的兜底：正常结束，不重试。
                    rm -f "$tmp"
                    log "容器 $name: 收到 204，视为正常到底。"
                    return 0
                    ;;
                401|403)
                    # 单页 401/403 授权拒绝，独立计数器 SWIFT_PAGE_AUTH_RETRIES。
                    ((page_401++))
                    if (( page_401 >= SWIFT_PAGE_AUTH_RETRIES )); then
                        log "容器 $name: 本页连续收到 $code 达 ${SWIFT_PAGE_AUTH_RETRIES} 次（授权被永久拒绝），该页失败，跳过容器。"
                        rm -f "$tmp"; return 3
                    fi
                    if auth; then
                        auth_failures=0
                    else
                        ((auth_failures++))
                        if (( auth_failures >= SWIFT_AUTH_RETRIES )); then
                            log "容器 $name: 重新认证连续失败达 ${SWIFT_AUTH_RETRIES} 次，视为认证永久失败，跳过容器。"
                            rm -f "$tmp"; return 2
                        fi
                    fi
                    sleep 1
                    # 用（可能新的）token 重试本页；不计入 SWIFT_RETRIES 硬失败。
                    ;;
                404)
                    log "容器 $name: 收到 404（容器/资源缺失），跳过该容器。"
                    rm -f "$tmp"; return 4
                    ;;
                *)
                    # 其他非 200/204 状态码 → 固定次数重试。
                    if (( hand >= SWIFT_RETRIES )); then
                        log "容器 $name: HTTP $code 重试耗尽，跳过该容器。"
                        rm -f "$tmp"; return 1
                    fi
                    ((hand++)); sleep 1
                    ;;
            esac
        done
    done
}

# ---------------------------------------------------------------------------
# 主流程（D6 / 5.3）
# ---------------------------------------------------------------------------
main() {
    if (( $# != 1 )); then
        echo "用法: $0 <container_list_file>" >&2
        return 2
    fi
    local list_file="$1"
    local had_failure=0 rc=0 name list_out="" list_rc=0
    local -a containers

    validate_env || return 1

    # 用命令替换捕获 list_containers 的退出码：进程替换 <() 会吞掉子进程返回码，
    # 导致"容器列表文件不存在"被误判为"空列表成功"(退出码 0 而非 1, P3)。
    # 注意 herestring/空输出会给一个空行，故仅当输出非空时才填充数组。
    list_out="$(list_containers "$list_file")" || list_rc=$?
    if (( list_rc != 0 )); then
        return 1
    fi
    containers=()
    if [[ -n "$list_out" ]]; then
        while IFS= read -r name; do
            containers+=("$name")
        done <<< "$list_out"
    fi

    if (( ${#containers[@]} == 0 )); then
        log "容器列表为空或全部为注释/空行，未处理任何容器。"
        return 0
    fi

    for name in "${containers[@]}"; do
        # 单容器失败以 || true 保护，避免 set -e 提前退出漏跑后续容器。
        pull_container "$name" && rc=0 || rc=$?
        if (( rc != 0 )); then
            log "容器 $name 失败（code=$rc）。"
            had_failure=1
        fi
    done

    if (( had_failure )); then
        log "存在容器处理失败，返回非零退出码。"
        return 1
    fi
    log "全部容器处理完成。"
    return 0
}

main "$@"
