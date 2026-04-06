#!/bin/bash
set -euo pipefail

# Download and process Environment Agency flood zone data for England
# Requires: python3, ogr2ogr (GDAL)
# Output:   ./output/flood-zones.geojson
#
# Data source: environment.data.gov.uk (Open Government Licence)
# Flood Zone 2 = medium probability, Flood Zone 3 = high probability

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${SCRIPT_DIR}/output"
TMPDIR="${OUTDIR}/flood-tmp"

mkdir -p "${OUTDIR}" "${TMPDIR}"

for cmd in python3 ogr2ogr; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "ERROR: ${cmd} not found."
        echo "  sudo apt install python3 gdal-bin"
        exit 1
    fi
done

echo "=== Environment Agency Flood Zone Builder ==="

# Flood Zone 2 (medium probability)
FZ2_URL="https://environment.data.gov.uk/UserDownloads/interactive/aff0d22a891b404ea8e62e75da38e4286170/EA_FloodMap_ForPlanningRivers_And_Sea_FloodZone2_SHP.zip"
# Flood Zone 3 (high probability)
FZ3_URL="https://environment.data.gov.uk/UserDownloads/interactive/aff0d22a891b404ea8e62e75da38e4286170/EA_FloodMap_ForPlanningRivers_And_Sea_FloodZone3_SHP.zip"

echo "[1/4] Downloading Flood Zone 2..."
wget -q --show-progress -O "${TMPDIR}/fz2.zip" "${FZ2_URL}" || {
    echo "WARNING: Download URL may have expired. Visit:"
    echo "  https://environment.data.gov.uk/DefraDataDownload/?mapService=EA/EA_FloodMapForPlanningRiversAndSea&Mode=spatial"
    echo "Download Flood Zone 2 and 3 shapefiles manually to ${TMPDIR}/"
    exit 1
}

echo "[2/4] Downloading Flood Zone 3..."
wget -q --show-progress -O "${TMPDIR}/fz3.zip" "${FZ3_URL}" || {
    echo "WARNING: Flood Zone 3 download failed. See above for manual download."
    exit 1
}

echo "[3/4] Extracting shapefiles..."
unzip -qo "${TMPDIR}/fz2.zip" -d "${TMPDIR}/fz2"
unzip -qo "${TMPDIR}/fz3.zip" -d "${TMPDIR}/fz3"

echo "[4/4] Processing into simplified GeoJSON..."
python3 "${SCRIPT_DIR}/process-flood-zones.py" \
    --fz2-dir "${TMPDIR}/fz2" \
    --fz3-dir "${TMPDIR}/fz3" \
    --output "${OUTDIR}/flood-zones.geojson"

rm -rf "${TMPDIR}"

echo "Done → ${OUTDIR}/flood-zones.geojson"
echo "Size: $(du -h "${OUTDIR}/flood-zones.geojson" | cut -f1)"
echo ""
echo "To build MBTiles for the map overlay:"
echo "  tippecanoe -o flood-zones.mbtiles -z14 -Z6 --drop-densest-as-needed ${OUTDIR}/flood-zones.geojson"
