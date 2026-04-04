#!/bin/bash -e

SYSCTL="${ROOTFS_DIR}/etc/sysctl.conf"
DHCPCD="${ROOTFS_DIR}/etc/dhcpcd.conf"

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> "${SYSCTL}"

# Static IP for wlan0, suppress wpa_supplicant hook
cat >> "${DHCPCD}" <<'EOF'

# Cairn hotspot — static IP on wlan0
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF

# Install config files
install -m 0644 files/hostapd.conf "${ROOTFS_DIR}/etc/hostapd/hostapd.conf"
install -m 0644 files/dnsmasq.conf  "${ROOTFS_DIR}/etc/dnsmasq.d/cairn.conf"

# Enable services inside the chroot
on_chroot << EOF
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
EOF
