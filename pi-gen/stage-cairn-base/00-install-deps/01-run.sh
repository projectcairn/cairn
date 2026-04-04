#!/bin/bash -e

# kiwix-serve 3.7.0 ARM64
KIWIX_VERSION="3.7.0"
KIWIX_ARCHIVE="kiwix-tools_linux-aarch64-${KIWIX_VERSION}.tar.gz"
KIWIX_URL="https://mirror.download.kiwix.org/release/kiwix-tools/${KIWIX_ARCHIVE}"

wget -q "${KIWIX_URL}" -O "/tmp/${KIWIX_ARCHIVE}"
tar -xzf "/tmp/${KIWIX_ARCHIVE}" -C /tmp
install -m 0755 "/tmp/kiwix-tools_linux-aarch64-${KIWIX_VERSION}/kiwix-serve" "${ROOTFS_DIR}/usr/local/bin/kiwix-serve"
rm -rf "/tmp/${KIWIX_ARCHIVE}" "/tmp/kiwix-tools_linux-aarch64-${KIWIX_VERSION}"

# mbtileserver 0.10.0 ARM64
MBTS_VERSION="0.10.0"
MBTS_ARCHIVE="mbtileserver_${MBTS_VERSION}_linux_arm64.tar.gz"
MBTS_URL="https://github.com/consbio/mbtileserver/releases/download/v${MBTS_VERSION}/${MBTS_ARCHIVE}"

wget -q "${MBTS_URL}" -O "/tmp/${MBTS_ARCHIVE}"
tar -xzf "/tmp/${MBTS_ARCHIVE}" -C /tmp
install -m 0755 /tmp/mbtileserver "${ROOTFS_DIR}/usr/local/bin/mbtileserver"
rm -f "/tmp/${MBTS_ARCHIVE}" /tmp/mbtileserver

# Create Cairn directories
mkdir -p \
    "${ROOTFS_DIR}/opt/cairn/zim" \
    "${ROOTFS_DIR}/opt/cairn/tiles" \
    "${ROOTFS_DIR}/opt/cairn/data" \
    "${ROOTFS_DIR}/opt/cairn/dashboard" \
    "${ROOTFS_DIR}/mnt/cairn-data"
