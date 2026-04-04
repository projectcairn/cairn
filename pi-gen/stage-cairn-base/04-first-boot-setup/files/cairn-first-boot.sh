#!/bin/bash
set -euo pipefail

CONFIG="/opt/cairn/config.json"
SETUP_FLAG="/opt/cairn/.setup-complete"

[ -f "$SETUP_FLAG" ] && exit 0

# ---- Detect hardware platform ----

PLATFORM="unknown"
MODEL="unknown"

if [ -f /sys/firmware/devicetree/base/model ]; then
    MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    PLATFORM="pi"
elif command -v lscpu >/dev/null 2>&1; then
    ARCH=$(lscpu | awk '/Architecture:/{print $2}')
    VENDOR=$(lscpu | awk -F: '/Model name:/{gsub(/^[ \t]+/,"",$2); print $2; exit}')
    MODEL="${VENDOR:-${ARCH}}"
    PLATFORM="x86"
fi

# ---- Detect RAM ----

RAM_KB=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
RAM_MB=$((RAM_KB / 1024))

# ---- Detect storage ----

ROOT_DEV=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//' | sed 's/p$//')
if [ -b "$ROOT_DEV" ]; then
    STORAGE_BYTES=$(blockdev --getsize64 "$ROOT_DEV" 2>/dev/null || echo 0)
else
    STORAGE_BYTES=$(df --output=size -B1 / | tail -1 | tr -d ' ')
fi
STORAGE_GB=$((STORAGE_BYTES / 1073741824))

# ---- Auto-select content tier ----

if [ "$STORAGE_GB" -lt 48 ]; then
    TIER="micro-32"
elif [ "$STORAGE_GB" -lt 100 ]; then
    TIER="micro-64"
elif [ "$STORAGE_GB" -lt 200 ]; then
    TIER="micro-128"
elif [ "$STORAGE_GB" -lt 400 ]; then
    TIER="lite"
else
    TIER="standard"
fi

# ---- AI capability ----

AI_CAPABLE="false"
[ "$RAM_MB" -ge 4096 ] && AI_CAPABLE="true"

# ---- Write config ----

cat > "$CONFIG" << EOF
{
  "platform": "${PLATFORM}",
  "model": "${MODEL}",
  "ram_mb": ${RAM_MB},
  "storage_gb": ${STORAGE_GB},
  "recommended_tier": "${TIER}",
  "ai_capable": ${AI_CAPABLE},
  "setup_complete": false
}
EOF

chmod 644 "$CONFIG"
echo "cairn-first-boot: config written to ${CONFIG}"
