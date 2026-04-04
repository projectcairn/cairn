#!/bin/bash -e

# Pi-gen stage: install Cairn dashboard and supporting scripts

CAIRN_DIR="${ROOTFS_DIR}/opt/cairn"

install -d "${CAIRN_DIR}/dashboard"
install -d "${CAIRN_DIR}/scripts"
install -d "${ROOTFS_DIR}/var/log/cairn"

cp -a "${STAGE_DIR}/../../../../../../dashboard/"* "${CAIRN_DIR}/dashboard/"

install -m 755 "${STAGE_DIR}/../../../../../../scripts/health-check.sh" "${CAIRN_DIR}/scripts/"
install -m 755 "${STAGE_DIR}/../../../../../../scripts/content-detect.sh" "${CAIRN_DIR}/scripts/"

echo "1.0.0-alpha" > "${CAIRN_DIR}/VERSION"

# --- Health-check systemd timer ---

cat > "${ROOTFS_DIR}/etc/systemd/system/cairn-health-check.service" << 'UNIT'
[Unit]
Description=Cairn health check
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/cairn/scripts/health-check.sh
StandardOutput=journal
UNIT

cat > "${ROOTFS_DIR}/etc/systemd/system/cairn-health-check.timer" << 'UNIT'
[Unit]
Description=Run Cairn health check every 30 seconds

[Timer]
OnBootSec=10s
OnUnitActiveSec=30s
AccuracySec=5s

[Install]
WantedBy=timers.target
UNIT

on_chroot << 'CHROOT'
systemctl enable cairn-health-check.timer
CHROOT
