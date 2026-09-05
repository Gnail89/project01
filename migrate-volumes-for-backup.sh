#!/bin/bash
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE=""
VM_NAME=""
TIMESTAMP=""
POLL_INTERVAL="${POLL_INTERVAL:-30}"
POLL_TIMEOUT="${POLL_TIMEOUT:-1000}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE" >&2
}

check_env() {
    echo "Checking prerequisites..."
    for cmd in openstack; do
        if ! command -v "$cmd" &>/dev/null; then
            log "ERROR: $cmd not found"
            exit 1
        fi
    done
    log "OK: openstack CLI available"
    if ! openstack volume type list -f value -c Name 2>/dev/null | grep -Fxq "hw2"; then
        log "ERROR: hw2 volume type not found"
        exit 1
    fi
    log "OK: hw2 volume type exists"
}

read_vm_ids() {
    local file="$SCRIPT_DIR/vmid.txt"
    if [ ! -f "$file" ]; then
        echo "ERROR: $file not found. Please create it with one VM UUID per line." >&2
        exit 1
    fi
    local ids=()
    while IFS= read -r line || [ -n "$line" ]; do
        line="$(echo "$line" | tr -d '\r' | xargs)"
        [ -z "$line" ] && continue
        ids+=("$line")
    done < "$file"
    if [ ${#ids[@]} -eq 0 ]; then
        echo "ERROR: No valid VM UUID found in $file" >&2
        exit 1
    fi
    echo "${ids[@]}"
}

wait_for_volume() {
    local vol_id="$1"
    local target="${2:-available}"
    local elapsed=0
    while [ "$elapsed" -lt "$POLL_TIMEOUT" ]; do
        local status
        status=$(openstack volume show -f value -c status "$vol_id") || return 1
        if [ "$status" = "$target" ]; then
            log "OK: Volume $vol_id is $target"
            return 0
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    log "ERROR: Timeout waiting for volume $vol_id to become $target (after ${elapsed}s)"
    return 1
}

wait_for_image() {
    local img_id="$1"
    local target="${2:-active}"
    local elapsed=0
    while [ "$elapsed" -lt "$POLL_TIMEOUT" ]; do
        local status
        status=$(openstack image show -f value -c status "$img_id") || return 1
        if [ "$status" = "$target" ]; then
            log "OK: Image $img_id is $target"
            return 0
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    log "ERROR: Timeout waiting for image $img_id to become $target (after ${elapsed}s)"
    return 1
}

create_snapshot() {
    local vm_id="$1"
    VM_NAME=$(openstack server show -f value -c name "$vm_id") || return 1
    TIMESTAMP="${MOCK_TIMESTAMP:-$(date +%Y%m%d%H%M%S)}"
    local snap_name="${VM_NAME}-backup-wangluogejie-${TIMESTAMP}"
    log "Creating VM snapshot: $snap_name"
    if ! openstack server image create --wait --name "$snap_name" "$vm_id"; then
        log "ERROR: Failed to create snapshot for VM $vm_id"
        return 1
    fi
    log "OK: Snapshot created: $snap_name"
}

get_volume_list() {
    local vm_id="$1"
    openstack server show -f value -c volumes_attached "$vm_id" |sed -e "s/id=//g" -e "s/'//g" || return 1
}

migrate_volume() {
    local vm_id="$1" vol_id="$2" vol_index="$3"
    log "--- Processing volume $vol_index: $vol_id ---"

    local vol_name
    vol_name=$(openstack volume show -f value -c name "$vol_id") || return 1
    local vol_size
    vol_size=$(openstack volume show -f value -c size "$vol_id") || return 1
    log "Volume: $vol_name, Size: ${vol_size}G"

    local snap_id
    snap_id=$(openstack volume snapshot list --volume "$vol_id" -f value -c ID -c Name | \
        grep "${VM_NAME}-backup-wangluogejie-${TIMESTAMP}" | awk '{print $1}') || true
    if [ -z "$snap_id" ]; then
        log "ERROR: No matching snapshot for volume $vol_id"
        return 1
    fi
    log "Matched snapshot: $snap_id"

    local base_name="${vol_name}-${vol_index}-backup-wangluogejie-${TIMESTAMP}"

    # Step 1: Create temp volume (hw) from snapshot
    log "Step 1/3: Creating temp volume (hw): $base_name"
    local vol_linshi_id
    vol_linshi_id=$(openstack volume create --type hw --snapshot "$snap_id" "$base_name" -f value -c id) || {
        log "ERROR: Failed to create temp volume for $vol_id"
        return 1
    }
    log "Temp volume created: $vol_linshi_id"
    if ! wait_for_volume "$vol_linshi_id"; then
        log "ERROR: Temp volume $vol_linshi_id not ready, skipping volume $vol_id"
        return 1
    fi

    # Step 2: Create Glance image from temp volume
    sleep 60
    log "Step 2/3: Creating image from temp volume: $base_name"
    local img_id
    cat > "$SCRIPT_DIR/tmp.sh" << SCRIPT
#!/bin/bash
openstack image create --volume "$vol_linshi_id" --container-format bare --disk-format qcow2 "$base_name" -f value -c image_id > "$SCRIPT_DIR/tmp.txt"
SCRIPT
    chmod +x "$SCRIPT_DIR/tmp.sh"
    log "请在另一个 TTY 中手动执行: while true;do [ -f $SCRIPT_DIR/tmp.sh ] && sh $SCRIPT_DIR/tmp.sh && rm -f $SCRIPT_DIR/tmp.sh ;sleep 5;done"

    local elapsed=0
    img_id=""
    while [ "$elapsed" -lt "$POLL_TIMEOUT" ]; do
        if [ -f "$SCRIPT_DIR/tmp.txt" ] && [ -s "$SCRIPT_DIR/tmp.txt" ]; then
            img_id=$(cat "$SCRIPT_DIR/tmp.txt")
            rm -f "$SCRIPT_DIR/tmp.txt"
            break
        fi
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    rm -f "$SCRIPT_DIR/tmp.sh"

    if [ -z "$img_id" ]; then
        log "ERROR: Failed to create image for volume $vol_id"
        return 1
    fi
    log "Image created: $img_id"
    if ! wait_for_image "$img_id"; then
        log "ERROR: Image $img_id not active, skipping volume $vol_id"
        return 1
    fi

    # Step 3: Create backup volume (hw2) from image
    log "Step 3/3: Creating backup volume (hw2) from image: $base_name"
    local vol_bkp_id
    vol_bkp_id=$(openstack volume create --type hw2 --image "$img_id" --size "$vol_size" "$base_name" -f value -c id) || {
        log "ERROR: Failed to create backup volume for $vol_id"
        return 1
    }
    log "Backup volume created: $vol_bkp_id"
    if ! wait_for_volume "$vol_bkp_id"; then
        log "ERROR: Backup volume $vol_bkp_id not ready, skipping volume $vol_id"
        return 1
    fi
    log "OK: Backup volume ready: $vol_bkp_id ($base_name)"

    # Cleanup
    log "Cleaning up intermediate resources..."
    if ! openstack image delete "$img_id"; then
        log "WARN: Failed to delete image $img_id"
    fi
    if ! openstack volume snapshot delete "$snap_id"; then
        log "WARN: Failed to delete snapshot $snap_id"
    fi
    if ! openstack volume delete "$vol_linshi_id"; then
        log "WARN: Failed to delete temp volume $vol_linshi_id"
    fi

    echo "$vol_id|$vol_name|$vol_bkp_id|$base_name"
}

process_vm() {
    local vm_id="$1"
    LOG_FILE="$SCRIPT_DIR/logs/migrate-volumes-${vm_id}-$(date +%Y%m%d).log"
    mkdir -p "$SCRIPT_DIR/logs"
    log "Starting volume migration for VM: $vm_id"
    log "Log file: $LOG_FILE"

    if ! openstack server show -f json "$vm_id" &>/dev/null; then
        log "ERROR: VM $vm_id not found, skipping"
        return 1
    fi
    log "OK: VM $vm_id exists"

    if ! create_snapshot "$vm_id"; then
        log "ERROR: Snapshot creation failed for VM $vm_id, skipping"
        return 1
    fi

    local vol_list
    vol_list=$(get_volume_list "$vm_id") || {
        log "ERROR: Failed to get volume list for VM $vm_id, skipping"
        return 1
    }
    log "Found volumes:"
    while IFS= read -r v; do
        [ -n "$v" ] && log "  - $v"
    done <<< "$vol_list"

    local vol_results=()
    local vol_result
    local vol_fail=0
    local vol_index=0
    while IFS= read -r vol_id; do
        [ -z "$vol_id" ] && continue
        ((vol_index++))
        vol_result=$(migrate_volume "$vm_id" "$vol_id" "$vol_index") || {
            log "ERROR: Volume $vol_id migration failed, skipping"
            ((vol_fail++))
            continue
        }
        vol_results+=("$vol_result")
    done <<< "$vol_list"

    log "=== Migration Summary for VM: $vm_id ($VM_NAME) ==="
    log "Original Volume ID | Original Volume Name | New Volume ID | New Volume Name"
    for r in "${vol_results[@]}"; do
        log "$r"
    done
    if [ "$vol_fail" -gt 0 ]; then
        log "VM migration completed with $vol_fail volume failure(s)"
        return 1
    fi
    log "VM migration completed successfully"
    return 0
}

main() {
    local vm_ids
    vm_ids=($(read_vm_ids)) || exit 1

    check_env

    echo "Starting batch volume migration for ${#vm_ids[@]} VM(s)"
    echo "vmid.txt: $SCRIPT_DIR/vmid.txt"

    local total=${#vm_ids[@]}
    local success=0
    local fail=0

    for vm_id in "${vm_ids[@]}"; do
        if process_vm "$vm_id"; then
            ((success++))
        else
            ((fail++))
        fi
    done

    echo "========================================"
    echo "Batch migration completed: $total VM(s), $success success, $fail failed"
    echo "========================================"
    return "$fail"
}

main "$@"
