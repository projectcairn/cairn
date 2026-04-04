#!/bin/bash -e

SYSTEMD_DIR="${ROOTFS_DIR}/etc/systemd/system"
NGINX_AVAIL="${ROOTFS_DIR}/etc/nginx/sites-available"
NGINX_ENABLED="${ROOTFS_DIR}/etc/nginx/sites-enabled"

# Install systemd service files
install -m 0644 "${STAGE_DIR}/../../systemd/kiwix-serve.service"            "${SYSTEMD_DIR}/kiwix-serve.service"
install -m 0644 "${STAGE_DIR}/../../systemd/mbtileserver.service"            "${SYSTEMD_DIR}/mbtileserver.service"
install -m 0644 "${STAGE_DIR}/../../systemd/cairn-ai.service"                "${SYSTEMD_DIR}/cairn-ai.service"
install -m 0644 "${STAGE_DIR}/../../systemd/cairn-content-detect.service"    "${SYSTEMD_DIR}/cairn-content-detect.service"

# Install nginx config
install -m 0644 "${STAGE_DIR}/../../../config/nginx-cairn.conf" "${NGINX_AVAIL}/cairn"
ln -sf /etc/nginx/sites-available/cairn "${NGINX_ENABLED}/cairn"
rm -f "${NGINX_ENABLED}/default"

# Create cairn system user
on_chroot << EOF
adduser --system --no-create-home --group --shell /usr/sbin/nologin cairn
EOF

# Enable services
on_chroot << EOF
systemctl enable kiwix-serve
systemctl enable mbtileserver
systemctl enable cairn-content-detect
systemctl enable nginx
EOF
