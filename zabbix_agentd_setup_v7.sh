#!/bin/bash
set -e

###############################################################################
# Title: Zabbix Agent Installer (Refactored)
# Description: Download and install Zabbix Agent on RHEL, CentOS,
#              Ubuntu/Debian, and SUSE systems, supporting x86, x86_64, aarch64.
# 
# Usage:  zabbix_agentd_setup.sh [-u user] [-d dir] [-s server]
# Options:
#   -u <user>     : non-root installation user (default: zabbix)
#   -d <dir>      : target installation directory (default: $HOME)
#   -s <server>   : Zabbix server/proxy IP (required)
#   -h            : show help and exit
# 
###############################################################################

# Configuration
export PATH="/bin:/usr/bin:/sbin:/usr/sbin"
ZABBIX_VERSION_LINUX="7.0.25"
ZABBIX_VERSION_AARCH64="7.0.25"
ZABBIX_VERSION_LINUXi386="3.0.10"
RES_SERVERS=(
  "172.17.1.1:8080"
  "172.16.2.1:8080"
)
declare -A ZABBIX_SERVERS=(
  ["172.17.1.1"]=10051
  ["172.16.2.1"]=10051
)

# Global variables
USER=""
TARGET=""
SERVER=""
INST_DIR=""
DAEMON_SCRIPT=""
CRON_ENTRY=""
ARCHIVE_NAME=""
HOST_IP=""

# Helpers
log() { echo "[INFO] $(date +'%F %T') $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }
usage() {
    sed -n '4,16p' "$0" | sed 's/# //'
    check_zbx_port
    exit 0
}


check_port(){
    local host="$1"
    local port="$2"
    local timeout=${3:-1}
    if timeout $timeout bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; then
      return 0
    else
      return 1
    fi
}


check_zbx_port(){ 
    for host in "${!ZABBIX_SERVERS[@]}"; do
        port=${ZABBIX_SERVERS[$host]}
        if check_port "$host" "$port" 1; then
            log "Zabbix Server found at $host:$port"
        fi
    done
}


parse_arguments() {
    USER="zabbix"
    TARGET=""
    SERVER=""
    while getopts ":u:d:s:h" opt; do
        case $opt in
            u) USER=$OPTARG ;;
            d) TARGET=$OPTARG ;;
            s) SERVER=$OPTARG ;;
            h) usage ;;
            *) err "Invalid option: -$OPTARG" ;;
        esac
    done
    [ -z "$SERVER" ] && err "Option -s <server> is required."

    if [ -z "$TARGET" ]; then
        TARGET="$HOME"
        [ -z "$TARGET" ] && err "Cannot resolve home for user $USER"
    fi

    INST_DIR="${TARGET}/zbx_agentd"
    DAEMON_SCRIPT="${INST_DIR}/zabbix_script.sh"
    CRON_ENTRY="* * * * * /bin/sh ${DAEMON_SCRIPT} daemon >/dev/null 2>&1"
}


check_environment() {
    if [ "$(id -u)" -eq 0 ]; then
        err "Must be run as non-root user (sudo discouraged)."
    fi

    for cmd in curl tar ip; do
        command -v "$cmd" >/dev/null || err "$cmd is required but not installed."
    done

    if [ ! -d "$TARGET" ]; then
        err "Target directory $TARGET does not exist"
    fi
}


detect_os_arch() {
    OS_ID="unknown"
    if [ -f /etc/os-release ]; then
        . /etc/os-release && OS_ID=$ID
    fi

    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            ARCH="x86_64"
            ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_LINUX}-1.linux.${ARCH}.tar.gz"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_AARCH64}-1.linux.${ARCH}.tar.gz"
            ;;
        i?86)
            ARCH="i386"
            ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_LINUXi386}-1.linux.${ARCH}.tar.gz"
            ;;
        *) err "Unsupported architecture: $arch" ;;
    esac
    log "Detected OS: $OS_ID, Architecture: $ARCH"
}


download_package() {
    cd "$TARGET" >/dev/null
    for host in "${RES_SERVERS[@]}"; do
        URL="http://${host}/software/zabbix-7.0/agent/${ARCHIVE_NAME}"
        log "Attempting download from $URL"
        if curl -fsSL --connect-timeout 2 -o "$ARCHIVE_NAME" "$URL"; then
            log "Downloaded $ARCHIVE_NAME"
            break
        fi
    done
    if [ ! -f "$ARCHIVE_NAME" ]; then
        err "Failed to download $ARCHIVE_NAME"
    fi
}


extract_and_install() {
    log "Extracting $ARCHIVE_NAME..."
    tar -xzf "$ARCHIVE_NAME" -C "$TARGET" || err "Extraction failed"
    log "Extraction completed to $TARGET"
}


detect_host_ip() {
    log "Detecting primary IP..."
    local ifname
    ifname="$(awk '$2 == "00000000" {print $1}' /proc/net/route | head -1)"
    if [ -z "$ifname" ]; then
        log "No default route found, prompting for IP."
        read -t 30 -p "Enter host primary IP: " -n 64 HOST_IP
        [ -z "$HOST_IP" ] && err "Cannot detect or provide host IP."
    else
        HOST_IP=$(ip addr show dev "$ifname" | grep -Eo "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | head -1)
        [ -z "$HOST_IP" ] && err "Failed to retrieve host IP."
    fi
    log "Host IP: $HOST_IP"
}


configure_agent() {
    log "Configuring Zabbix agent..."
    cat > "${INST_DIR}/etc/zabbix_agentd.conf" <<EOF
PidFile=${INST_DIR}/zabbix_agentd.pid
LogFile=${INST_DIR}/zabbix_agentd.log
AllowKey=system.run[*]
LogRemoteCommands=1
StartAgents=0
ServerActive=${SERVER}
Hostname=${HOST_IP}
HostMetadataItem=system.uname
UnsafeUserParameters=1
TLSConnect=psk
TLSAccept=psk
TLSPSKIdentity=ZBX_CLIENT_001
TLSPSKFile=${INST_DIR}/certs/zabbix_agentd.psk
Include=${INST_DIR}/etc/zabbix_agentd.conf.d/*.conf
EOF
    sed -i "s|%change_basepath%|${INST_DIR}|g" "${DAEMON_SCRIPT}"

    if [ -d "${INST_DIR}/etc/zabbix_agentd.conf.d" ]; then
        while IFS= read -r -d '' conf_file; do
            sed -i "s|%change_basepath%|${INST_DIR}|g" "$conf_file" || err "Failed to modify $conf_file"
        done < <(find "${INST_DIR}/etc/zabbix_agentd.conf.d" -type f -name "*.conf" -print0)
    else
        err "Directory ${INST_DIR}/etc/zabbix_agentd.conf.d does not exist."
    fi
    log "Configuration completed."
}


backup_crontab() {
    if crontab -l 2>/dev/null; then
        BACKUP_FILE="${TARGET}/crontab_backup_$(date +'%Y%m%d%H%M%S').bak"
        crontab -l > "$BACKUP_FILE" && log "Crontab backed up to $BACKUP_FILE"
    else
        log "No existing crontab found."
    fi
}


setup_cron() {
    log "Setting up cron job..."
    (crontab -l 2>/dev/null | grep -v -F "$DAEMON_SCRIPT"; echo "$CRON_ENTRY") | crontab - || err "Failed to setup cron job"
    log "Cron job added successfully."
}


print_summary() {
    log "Zabbix Agent ${ARCHIVE_NAME} installed successfully in ${INST_DIR}."
    log "Managed by user ${USER}, OS ${OS_ID}, ARCH ${ARCH}"
}


main() {
    parse_arguments "$@"
    check_environment
    detect_os_arch
    download_package
    extract_and_install
    detect_host_ip
    configure_agent
    backup_crontab
    setup_cron
    print_summary
}

main "$@"
