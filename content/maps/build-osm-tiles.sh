#!/bin/bash
set -euo pipefail

# Build Great Britain vector MBTiles from OpenStreetMap data
# Requires: tilemaker (apt install tilemaker or build from source)
# Output:   ./output/gb-osm.mbtiles
#
# Download size: ~1.2 GB PBF, output ~2-4 GB MBTiles depending on zoom
# Build time: 30-90 minutes depending on hardware

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${SCRIPT_DIR}/output"
CONFIG_DIR="${SCRIPT_DIR}/tilemaker-config"
PBF_URL="https://download.geofabrik.de/europe/great-britain-latest.osm.pbf"
PBF_FILE="${OUTDIR}/great-britain-latest.osm.pbf"
MBTILES_FILE="${OUTDIR}/gb-osm.mbtiles"

mkdir -p "${OUTDIR}"

if ! command -v tilemaker &>/dev/null; then
    echo "ERROR: tilemaker not found."
    echo "Install with: sudo apt install tilemaker"
    echo "Or build from source: https://github.com/systemed/tilemaker"
    exit 1
fi

echo "=== Great Britain OSM Tile Builder ==="

if [ -f "${PBF_FILE}" ]; then
    echo "PBF file already exists: ${PBF_FILE}"
    echo "Delete it to re-download."
else
    echo "[1/2] Downloading Great Britain PBF (~1.2 GB)..."
    wget -q --show-progress -O "${PBF_FILE}" "${PBF_URL}"
fi

echo "[2/2] Building vector tiles (zoom 0-14)..."
echo "This will take a while — 30-90 minutes depending on hardware."

tilemaker \
    --input "${PBF_FILE}" \
    --output "${MBTILES_FILE}" \
    --config "${CONFIG_DIR}/config.json" \
    --process "${CONFIG_DIR}/process.lua" \
    --bbox -8.2,49.9,1.8,60.9 \
    --skip-integrity

echo "Done → ${MBTILES_FILE}"
echo "Size: $(du -h "${MBTILES_FILE}" | cut -f1)"
echo ""
echo "Copy to your Cairn node:"
echo "  scp ${MBTILES_FILE} cairn:/opt/cairn/tiles/"
