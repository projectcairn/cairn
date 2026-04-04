#!/bin/bash -e

# Pi-gen stage: install first-boot hardware detection service

CAIRN_DIR="${ROOTFS_DIR}/opt/cairn"

install -d "${CAIRN_DIR}/scripts"
install -m 755 "${STAGE_DIR}/files/cairn-first-boot.sh" "${CAIRN_DIR}/scripts/"

cat > "${ROOTFS_DIR}/etc/systemd/system/cairn-first-boot.service" << 'UNIT'
[Unit]
Description=Cairn first-boot hardware detection
After=local-fs.target
Before=cairn-health-check.timer

[Service]
Type=oneshot
ExecStart=/opt/cairn/scripts/cairn-first-boot.sh
RemainAfterExit=yes
ConditionPathExists=!/opt/cairn/.setup-complete

[Install]
WantedBy=multi-user.target
UNIT

on_chroot << 'CHROOT'
systemctl enable cairn-first-boot.service
CHROOT
