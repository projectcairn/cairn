#!/bin/bash -e

LOG_DIR="/var/log/cairn"
LOG_FILE="${LOG_DIR}/content.log"
LIBRARY_XML="/opt/cairn/zim/library.xml"
ZIM_DIRS=(
    "/opt/cairn/zim"
    "/mnt/cairn-data"
)

mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date -Iseconds)] $*" | tee -a "${LOG_FILE}"
}

log "Starting content detection"

# Rebuild kiwix library from scratch
if [ -f "${LIBRARY_XML}" ]; then
    rm "${LIBRARY_XML}"
fi

found=0
for dir in "${ZIM_DIRS[@]}"; do
    if [ ! -d "${dir}" ]; then
        log "Directory not found, skipping: ${dir}"
        continue
    fi

    while IFS= read -r -d '' zim; do
        log "Adding ZIM: ${zim}"
        kiwix-manage "${LIBRARY_XML}" add "${zim}" && found=$((found + 1)) || \
            log "WARNING: failed to add ${zim}"
    done < <(find "${dir}" -maxdepth 3 -name "*.zim" -print0)
done

log "Added ${found} ZIM file(s) to library"

# Restart kiwix-serve to pick up the new library
if systemctl is-active --quiet kiwix-serve; then
    systemctl restart kiwix-serve
    log "kiwix-serve restarted"
else
    log "kiwix-serve is not active — skipping restart"
fi

log "Content detection complete"
