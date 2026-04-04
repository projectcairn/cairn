#!/bin/bash

STATUS_FILE="/opt/cairn/data/system-status.json"
VERSION_FILE="/opt/cairn/VERSION"

# ---------- platform -------------------------------------------------------
platform="unknown"
cpu_temp="null"

if [ -f /sys/firmware/devicetree/base/model ]; then
    pi_model=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
    platform="${pi_model}"
    # vcgencmd available on Pi
    if command -v vcgencmd &>/dev/null; then
        raw=$(vcgencmd measure_temp 2>/dev/null | grep -oP '[0-9]+\.[0-9]+')
        [ -n "${raw}" ] && cpu_temp="${raw}"
    fi
else
    platform=$(lscpu 2>/dev/null | awk -F': +' '/^Architecture/{print $2}' || echo "x86")
    # lm-sensors on x86
    if command -v sensors &>/dev/null; then
        raw=$(sensors 2>/dev/null | grep -m1 'Core 0' | grep -oP '\+[0-9]+\.[0-9]+' | tr -d '+' || true)
        [ -n "${raw}" ] && cpu_temp="${raw}"
    fi
fi

# ---------- CPU cores -------------------------------------------------------
cpu_cores=$(nproc 2>/dev/null || echo "null")

# ---------- RAM (kB → MB) ---------------------------------------------------
ram_total=$(awk '/^MemTotal/{printf "%.0f", $2/1024}' /proc/meminfo)
ram_free=$(awk  '/^MemAvailable/{printf "%.0f", $2/1024}' /proc/meminfo)
ram_used=$((ram_total - ram_free))

# ---------- Disk for /opt/cairn ---------------------------------------------
read -r disk_total disk_used disk_free _ < <(df -BM /opt/cairn 2>/dev/null | \
    awk 'NR==2{gsub(/M/,"",$2); gsub(/M/,"",$3); gsub(/M/,"",$4); print $2, $3, $4}')
disk_total=${disk_total:-0}
disk_used=${disk_used:-0}
disk_free=${disk_free:-0}

# ---------- service status --------------------------------------------------
svc_status() {
    local svc="$1"
    systemctl is-active --quiet "${svc}" 2>/dev/null && echo "active" || echo "inactive"
}

svc_kiwix=$(svc_status kiwix-serve)
svc_mbtiles=$(svc_status mbtileserver)
svc_ai=$(svc_status cairn-ai)
svc_hostapd=$(svc_status hostapd)
svc_nginx=$(svc_status nginx)

# ---------- WiFi client count -----------------------------------------------
wifi_clients="null"
if command -v hostapd_cli &>/dev/null && systemctl is-active --quiet hostapd; then
    count=$(hostapd_cli all_sta 2>/dev/null | grep -c '^[0-9a-f]\{2\}:' || true)
    wifi_clients="${count}"
fi

# ---------- uptime (seconds) ------------------------------------------------
uptime_seconds=$(awk '{printf "%.0f", $1}' /proc/uptime)

# ---------- version ---------------------------------------------------------
cairn_version="unknown"
[ -f "${VERSION_FILE}" ] && cairn_version=$(cat "${VERSION_FILE}" | tr -d '[:space:]')

# ---------- emit JSON -------------------------------------------------------
mkdir -p "$(dirname "${STATUS_FILE}")"

cat > "${STATUS_FILE}" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "version": "${cairn_version}",
  "platform": $(printf '%s' "${platform}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),
  "cpu": {
    "cores": ${cpu_cores},
    "temp_c": ${cpu_temp}
  },
  "ram_mb": {
    "total": ${ram_total},
    "used": ${ram_used},
    "free": ${ram_free}
  },
  "disk_mb": {
    "total": ${disk_total},
    "used": ${disk_used},
    "free": ${disk_free}
  },
  "services": {
    "kiwix-serve": "${svc_kiwix}",
    "mbtileserver": "${svc_mbtiles}",
    "cairn-ai": "${svc_ai}",
    "hostapd": "${svc_hostapd}",
    "nginx": "${svc_nginx}"
  },
  "wifi_clients": ${wifi_clients},
  "uptime_seconds": ${uptime_seconds}
}
EOF
