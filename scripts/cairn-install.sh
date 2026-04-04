#!/bin/bash
set -euo pipefail

# ============================================================================
# Project Cairn — x86 installer
# Usage: curl -sSL https://projectcairn.org.uk/install | bash
# ============================================================================

CAIRN_VERSION="1.0.0-alpha"
KIWIX_VERSION="3.7.0"
MBTILES_VERSION="0.11.0"
REPO_URL="https://github.com/projectcairn/cairn.git"
CAIRN_DIR="/opt/cairn"
NONINTERACTIVE="${CAIRN_NONINTERACTIVE:-0}"
SKIP_CONTENT="${CAIRN_SKIP_CONTENT:-0}"

# ---- colours ---------------------------------------------------------------

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
fail()  { echo -e "${RED}[✗]${NC} $*"; }
die()   { fail "$*"; exit 1; }

# ---- banner ----------------------------------------------------------------

echo ""
echo "==========================================="
echo "       === Project Cairn Installer ==="
echo "==========================================="
echo "  Version: ${CAIRN_VERSION}"
echo ""

# ---- root check ------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root (try: sudo bash)"
fi

# ---- OS check --------------------------------------------------------------

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if echo "${ID:-} ${ID_LIKE:-}" | grep -qiE 'ubuntu|debian'; then
        info "Detected OS: ${PRETTY_NAME:-${ID}}"
    else
        warn "Unsupported OS: ${PRETTY_NAME:-${ID}}. Script is designed for Debian/Ubuntu."
        warn "Continuing anyway — some packages may not install correctly."
    fi
else
    warn "/etc/os-release not found. Cannot verify OS."
fi

# ---- hardware detection ----------------------------------------------------

RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
DISK_FREE_GB=$(df -BG / | awk 'NR==2{gsub(/G/,"",$4); print $4}')
CPU_CORES=$(nproc 2>/dev/null || echo "?")
ARCH=$(uname -m)

echo ""
info "Hardware detected:"
echo "    CPU:      ${CPU_CORES} cores (${ARCH})"
echo "    RAM:      ${RAM_MB} MB"
echo "    Disk free: ${DISK_FREE_GB} GB"
echo ""

if [ "${ARCH}" != "x86_64" ]; then
    warn "This installer is designed for x86_64. Detected: ${ARCH}"
    warn "For Raspberry Pi, use the pi-gen image instead."
fi

# ---- update check ----------------------------------------------------------

if [ -f "${CAIRN_DIR}/dashboard/index.html" ]; then
    warn "Existing Cairn installation detected at ${CAIRN_DIR}"
    if [ "${NONINTERACTIVE}" = "1" ]; then
        info "Non-interactive mode — proceeding with update"
    else
        read -r -p "Update existing installation? (Y/n) " ans
        case "${ans}" in n*|N*) echo "Aborted."; exit 0;; esac
    fi
fi

# ---- install apt dependencies ----------------------------------------------

info "Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    nginx dnsmasq sqlite3 jq curl wget unzip rsync git \
    python3-minimal hostapd cryptsetup >/dev/null 2>&1
info "System packages installed"

# ---- create directories ----------------------------------------------------

info "Creating Cairn directories..."
mkdir -p "${CAIRN_DIR}"/{zim,tiles,data,dashboard,models,scripts,vaults}
mkdir -p /var/log/cairn

# ---- create system user ----------------------------------------------------

if ! id cairn &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin cairn
    info "Created system user: cairn"
else
    info "System user cairn already exists"
fi

chown -R cairn:cairn "${CAIRN_DIR}"/{zim,tiles,data,models,vaults}

# ---- install kiwix-serve ---------------------------------------------------

if [ ! -x /usr/local/bin/kiwix-serve ] || ! kiwix-serve --version 2>&1 | grep -q "${KIWIX_VERSION}"; then
    info "Installing kiwix-serve ${KIWIX_VERSION}..."
    KIWIX_URL="https://download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-x86_64-${KIWIX_VERSION}.tar.gz"
    TMP_KW=$(mktemp -d)
    curl -sSL "${KIWIX_URL}" | tar xz -C "${TMP_KW}" --strip-components=1
    install -m 755 "${TMP_KW}/kiwix-serve" /usr/local/bin/
    install -m 755 "${TMP_KW}/kiwix-manage" /usr/local/bin/
    rm -rf "${TMP_KW}"
    info "kiwix-serve ${KIWIX_VERSION} installed"
else
    info "kiwix-serve ${KIWIX_VERSION} already installed"
fi

# ---- install mbtileserver --------------------------------------------------

if [ ! -x /usr/local/bin/mbtileserver ] || ! mbtileserver --version 2>&1 | grep -q "${MBTILES_VERSION}"; then
    info "Installing mbtileserver ${MBTILES_VERSION}..."
    MBT_URL="https://github.com/consbio/mbtileserver/releases/download/v${MBTILES_VERSION}/mbtileserver_v${MBTILES_VERSION}_linux_amd64.zip"
    TMP_MB=$(mktemp -d)
    wget -qO "${TMP_MB}/mbtileserver.zip" "${MBT_URL}"
    unzip -qo "${TMP_MB}/mbtileserver.zip" -d "${TMP_MB}"
    install -m 755 "${TMP_MB}/mbtileserver" /usr/local/bin/mbtileserver
    rm -rf "${TMP_MB}"
    info "mbtileserver ${MBTILES_VERSION} installed"
else
    info "mbtileserver ${MBTILES_VERSION} already installed"
fi

# ---- clone repo and copy files ---------------------------------------------

if [ -n "${CAIRN_SRC_DIR:-}" ] && [ -d "${CAIRN_SRC_DIR}/dashboard" ]; then
    info "Using local source: ${CAIRN_SRC_DIR}"
    TMP_SRC="${CAIRN_SRC_DIR}"
    LOCAL_SRC=1
else
    info "Fetching Cairn source..."
    TMP_SRC=$(mktemp -d)
    git clone --depth 1 --quiet "${REPO_URL}" "${TMP_SRC}"
    LOCAL_SRC=0
fi

info "Installing dashboard..."
rsync -a --delete "${TMP_SRC}/dashboard/" "${CAIRN_DIR}/dashboard/"
chown -R cairn:cairn "${CAIRN_DIR}/dashboard"

info "Installing scripts..."
install -m 755 "${TMP_SRC}/scripts/health-check.sh" "${CAIRN_DIR}/scripts/"
install -m 755 "${TMP_SRC}/scripts/content-detect.sh" "${CAIRN_DIR}/scripts/"
install -m 755 "${TMP_SRC}/scripts/wifi-hotspot-setup.sh" "${CAIRN_DIR}/scripts/" 2>/dev/null || true
if [ -f "${TMP_SRC}/pi-gen/stage-cairn-base/04-first-boot-setup/files/cairn-first-boot.sh" ]; then
    install -m 755 "${TMP_SRC}/pi-gen/stage-cairn-base/04-first-boot-setup/files/cairn-first-boot.sh" "${CAIRN_DIR}/scripts/"
fi

info "Installing systemd units..."
cp "${TMP_SRC}/systemd/"*.service /etc/systemd/system/ 2>/dev/null || true

# Health-check timer (not in systemd/ dir — created by pi-gen stage)
cat > /etc/systemd/system/cairn-health-check.service << 'UNIT'
[Unit]
Description=Cairn health check
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/cairn/scripts/health-check.sh
StandardOutput=journal
UNIT

cat > /etc/systemd/system/cairn-health-check.timer << 'UNIT'
[Unit]
Description=Run Cairn health check every 30 seconds

[Timer]
OnBootSec=10s
OnUnitActiveSec=30s
AccuracySec=5s

[Install]
WantedBy=timers.target
UNIT

info "Configuring nginx..."
cp "${TMP_SRC}/config/nginx-cairn.conf" /etc/nginx/sites-available/cairn
ln -sf /etc/nginx/sites-available/cairn /etc/nginx/sites-enabled/cairn
rm -f /etc/nginx/sites-enabled/default
nginx -t -q 2>/dev/null || warn "nginx config test failed — check /etc/nginx/sites-available/cairn"

[ "${LOCAL_SRC}" = "0" ] && rm -rf "${TMP_SRC}"

# ---- version file ----------------------------------------------------------

echo "${CAIRN_VERSION}" > "${CAIRN_DIR}/VERSION"

# ---- touch the kiwix library so services can start -------------------------

touch "${CAIRN_DIR}/zim/library.xml"
chown cairn:cairn "${CAIRN_DIR}/zim/library.xml"

# ---- enable and start services ---------------------------------------------

info "Enabling services..."
systemctl daemon-reload

for svc in kiwix-serve mbtileserver nginx cairn-content-detect cairn-health-check.timer; do
    systemctl enable "${svc}" --quiet 2>/dev/null || true
    systemctl start "${svc}" 2>/dev/null || warn "Could not start ${svc}"
done
info "Core services started"

# ---- run first-boot detection ----------------------------------------------

info "Running hardware detection..."
if [ -x "${CAIRN_DIR}/scripts/cairn-first-boot.sh" ]; then
    bash "${CAIRN_DIR}/scripts/cairn-first-boot.sh" || warn "First-boot detection had errors"
    if [ -f "${CAIRN_DIR}/config.json" ]; then
        info "Hardware config written to ${CAIRN_DIR}/config.json"
    fi
fi

# ---- optional: local AI ----------------------------------------------------

if [ "${NONINTERACTIVE}" != "1" ] && [ "${RAM_MB}" -ge 4000 ]; then
    echo ""
    if [ "${RAM_MB}" -ge 8000 ]; then
        AI_MODEL_NAME="gemma-3-4b-it-Q4_K_M.gguf"
        AI_MODEL_URL="https://huggingface.co/bartowski/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf"
        AI_DESC="Gemma 3 4B (Q4_K_M) — better quality, needs ~3 GB RAM"
    else
        AI_MODEL_NAME="gemma-3-1b-it-Q4_K_M.gguf"
        AI_MODEL_URL="https://huggingface.co/bartowski/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf"
        AI_DESC="Gemma 3 1B (Q4_K_M) — lightweight, needs ~1.2 GB RAM"
    fi

    read -r -p "Install local AI? ${AI_DESC} (y/N) " ai_ans
    case "${ai_ans}" in
        y*|Y*)
            info "Downloading llama-server..."
            LLAMA_URL="https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-server-linux-x86_64.tar.gz"
            TMP_LL=$(mktemp -d)
            curl -sSL "${LLAMA_URL}" | tar xz -C "${TMP_LL}"
            install -m 755 "${TMP_LL}/llama-server" /usr/local/bin/
            rm -rf "${TMP_LL}"
            info "llama-server installed"

            info "Downloading model: ${AI_MODEL_NAME} (this may take a while)..."
            curl -sSL -o "${CAIRN_DIR}/models/${AI_MODEL_NAME}" "${AI_MODEL_URL}"
            chown cairn:cairn "${CAIRN_DIR}/models/${AI_MODEL_NAME}"

            # Update service to point at the right model file
            if [ "${AI_MODEL_NAME}" != "gemma-3-1b-it.gguf" ]; then
                sed -i "s|gemma-3-1b-it.gguf|${AI_MODEL_NAME}|g" /etc/systemd/system/cairn-ai.service
                systemctl daemon-reload
            fi

            systemctl enable cairn-ai --quiet
            systemctl start cairn-ai || warn "cairn-ai failed to start — check model file"
            info "Local AI enabled"
            ;;
    esac
fi

# ---- optional: WiFi hotspot -----------------------------------------------

if [ "${NONINTERACTIVE}" != "1" ]; then
    echo ""
    read -r -p "Set up WiFi hotspot? (Requires compatible WiFi adapter) (y/N) " wifi_ans
    case "${wifi_ans}" in
        y*|Y*)
            if [ -x "${CAIRN_DIR}/scripts/wifi-hotspot-setup.sh" ]; then
                bash "${CAIRN_DIR}/scripts/wifi-hotspot-setup.sh"
            else
                warn "WiFi hotspot setup script not found. Configure manually with hostapd."
            fi
            ;;
    esac
fi

# ---- done ------------------------------------------------------------------

LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
LOCAL_IP=${LOCAL_IP:-"localhost"}

echo ""
echo "==========================================="
echo -e "  ${GREEN}Cairn installed successfully!${NC}"
echo "==========================================="
echo ""
echo "  Dashboard:  http://${LOCAL_IP}/"
echo "  Version:    ${CAIRN_VERSION}"
echo ""
echo "  Next steps:"
echo "    1. Open the dashboard to complete the setup wizard"
echo "    2. Download content packs from the Content section"
echo "    3. Add ZIM files to /opt/cairn/zim/ for offline reading"
echo "    4. Add .mbtiles to /opt/cairn/tiles/ for offline maps"
echo "    5. Add documents to /opt/cairn/data/ for file sharing"
echo ""
info "Installation complete"
