#!/bin/bash
set -e

###############################################################################
# Title: Zabbix Agent Installer
# Description: Download and install Zabbix Agent on RHEL, CentOS,
#              Ubuntu/Debian, and SUSE systems, supporting x86, x86_64, aarch64.
# 
# Usage:  zabbix_agentd_setup.sh [-u user] [-d dir] [-s server] [-i] [-q]
# Options:
#   -u <user>     : non-root installation user (default: zabbix)
#   -d <dir>      : target installation directory (default: \$HOME)
#   -s <server>   : Zabbix server/proxy IP (required)
#   -h            : show help and exit
# 
###############################################################################

# --- Configuration -----------------------------------------------------------
export PATH="/bin:/usr/bin:/sbin:/usr/sbin"
ZABBIX_VERSION_LINUX="4.0.1"
ZABBIX_VERSION_AARCH64="4.0.32"
ZABBIX_VERSION_LINUXi386="3.0.10"
RES_SERVERS=("172.17.1.1:8080" "172.16.2.1:8080")

# --- Helpers -----------------------------------------------------------------
function log() { echo "[INFO] $(date +'%F %T') $*"; }
function err() { echo "[ERROR] $*" >&2; exit 1; }
function usage() {
    sed -n '4,16p' "$0" | sed 's/# //'
    exit 0
}

# --- Parse Options -----------------------------------------------------------
USER="zabbix"; TARGET=""; SERVER=""
while getopts ":u:d:s:h" opt; do
    case $opt in
        u) USER=$OPTARG ;; d) TARGET=$OPTARG ;; s) SERVER=$OPTARG ;;
        h) usage ;; *) err "Invalid option: -$OPTARG" ;;
    esac
done

[ -z "$SERVER" ] && err "Option -s <server> is required."
if [ -z "$TARGET" ]; then
    TARGET="$HOME"
    [ -z "$TARGET" ] && err "Cannot resolve home for user $USER"
fi
INST_DIR="${TARGET}/zabbix_agentd"
CONFIG_DIR="${INST_DIR}/etc"
DAEMON_SCRIPT="${INST_DIR}/zabbix_script.sh"
CRON_ENTRY="*/10 * * * * /bin/sh ${DAEMON_SCRIPT} daemon >/dev/null 2>&1"

# --- Environment Checks -----------------------------------------------------
[ "$(id -u)" -eq 0 ] && err "Must be run as non-root user (sudo discouraged)."

# Check required commands
for cmd in curl tar ip; do
    command -v "$cmd" >/dev/null || err "$cmd is required but not installed."
done

# --- OS & Arch Detection ----------------------------------------------------
OS_ID="unknown"; ARCH="$(uname -m)"; ARCHIVE_NAME=""
if [ -f /etc/os-release ]; then
    . /etc/os-release && OS_ID=$ID
fi
case "$ARCH" in
  x86_64|amd64) ARCH="x86_64"; ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_LINUX}-1.linux.${ARCH}.tar.gz";;
  aarch64|arm64) ARCH="aarch64"; ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_AARCH64}-1.linux.${ARCH}.tar.gz";;
  i?86)         ARCH="i386"; ARCHIVE_NAME="zabbix-agentd-${ZABBIX_VERSION_LINUXi386}-1.linux.${ARCH}.tar.gz";;
  *) err "Unsupported architecture: $ARCH";;
esac

# --- Download Package -------------------------------------------------------
[ -d "$TARGET" ] || err "Target directory $TARGET does not exist"
cd "$TARGET" >/dev/null
for host in "${RES_SERVERS[@]}"; do
    URL="http://${host}/software/zabbix-4.0/zabbix_agentd_linux/${ARCHIVE_NAME}"
    log "Attempting download from $URL"
    if curl -fsSL --connect-timeout 10 -o "$ARCHIVE_NAME" "$URL"; then
        log "Downloaded $ARCHIVE_NAME"
        break
    fi
done
[ ! -f "$ARCHIVE_NAME" ] && err "Failed to download $ARCHIVE_NAME"

# --- Extract and Install ----------------------------------------------------
log "Extracting $ARCHIVE_NAME..."
tar -xzf "$ARCHIVE_NAME" -C "$TARGET" || err "Extraction failed"

# --- Get primary IP ----------------------------------------------------------
log "Detecting primary IP..."
HOST_IP=""
IFNAME="$(awk '$2 == "00000000" {print $1}' /proc/net/route |head -1)"
if [ -z "$IFNAME" ]; then
    log "No default route found, prompting for IP."
    read -t 30 -p "Enter host primary IP: " -n 64 HOST_IP
    [ -z "$HOST_IP" ] && err "Cannot detect or provide host IP."
else
    HOST_IP=$(ip addr show dev "$IFNAME" | grep -Eo "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | head -1)
    [ -z "$HOST_IP" ] && err "Failed to retrieve host IP."
fi

# --- Configure Agent --------------------------------------------------------
log "Configuring Zabbix agent..."
sed -i \
    -e "s|%change_hostname%|${HOST_IP}|g" \
    -e "s|%change_serverip%|${SERVER}|g" \
    -e "s|%change_basepath%|${INST_DIR}|g" \
    "${CONFIG_DIR}/zabbix_agentd.conf"
sed -i "s|%change_basepath%|${INST_DIR}|g" "${DAEMON_SCRIPT}"
if [ -d "${CONFIG_DIR}/zabbix_agentd.conf.d" ]; then
    find "${CONFIG_DIR}/zabbix_agentd.conf.d" -type f -name "*.conf" -print0 | while IFS= read -r -d '' conf_file; do
        sed -i "s|%change_basepath%|${INST_DIR}|g" "$conf_file" || err "Failed to modify $conf_file"
    done
else
    err "Directory ${CONFIG_DIR}/zabbix_agentd.conf.d does not exist."
fi

# --- Backup Existing Crontab ------------------------------------------------
if crontab -l 2>/dev/null; then
    BACKUP_FILE="${TARGET}/crontab_backup_$(date +'%Y%m%d%H%M%S').bak"
    crontab -l > "$BACKUP_FILE" && log "Crontab backed up to $BACKUP_FILE"
else
    log "No existing crontab found."
fi

# --- Cron Setup -------------------------------------------------------------
log "Setting up cron job..."
(crontab -l 2>/dev/null | grep -v -F "$DAEMON_SCRIPT"; echo "$CRON_ENTRY") | crontab - || err "Failed to setup cron job"

# --- Final ------------------------------------------------------------------
log "Zabbix Agent ${ARCHIVE_NAME} installed successfully in ${INST_DIR}."
log "Managed by user ${USER}, OS ${OS_ID}, ARCH ${ARCH}"
