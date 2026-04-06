#!/bin/bash
set -euo pipefail

# Build OS Open Zoomstack overlay MBTiles
# Requires: ogr2ogr (GDAL), tippecanoe
#
# NOTE: You must download OS Open Zoomstack manually:
#   1. Register at https://osdatahub.os.uk
#   2. Download "OS Open Zoomstack" in GeoPackage format
#   3. Save as ./input/OS_Open_Zoomstack.gpkg
#
# Output: ./output/os-overlay.mbtiles

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INPUT_DIR="${SCRIPT_DIR}/input"
OUTDIR="${SCRIPT_DIR}/output"
TMPDIR="${OUTDIR}/os-tmp"
GPKG="${INPUT_DIR}/OS_Open_Zoomstack.gpkg"
MBTILES="${OUTDIR}/os-overlay.mbtiles"

mkdir -p "${OUTDIR}" "${TMPDIR}"

if [ ! -f "${GPKG}" ]; then
    echo "ERROR: OS Open Zoomstack GeoPackage not found."
    echo ""
    echo "Please download it manually:"
    echo "  1. Go to https://osdatahub.os.uk/downloads/open/OpenZoomstack"
    echo "  2. Download the GeoPackage format"
    echo "  3. Save to: ${GPKG}"
    exit 1
fi

for cmd in ogr2ogr tippecanoe; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "ERROR: ${cmd} not found."
        echo "Install with:"
        echo "  sudo apt install gdal-bin   # for ogr2ogr"
        echo "  # tippecanoe: https://github.com/felt/tippecanoe"
        exit 1
    fi
done

echo "=== OS Open Zoomstack Overlay Builder ==="

echo "[1/4] Extracting roads..."
ogr2ogr -f GeoJSON "${TMPDIR}/roads.geojson" "${GPKG}" \
    -sql "SELECT * FROM Roads" -t_srs EPSG:4326 2>/dev/null

echo "[2/4] Extracting woodland..."
ogr2ogr -f GeoJSON "${TMPDIR}/woodland.geojson" "${GPKG}" \
    -sql "SELECT * FROM Woodland" -t_srs EPSG:4326 2>/dev/null

echo "[3/4] Extracting surface water..."
ogr2ogr -f GeoJSON "${TMPDIR}/water.geojson" "${GPKG}" \
    -sql "SELECT * FROM SurfaceWater" -t_srs EPSG:4326 2>/dev/null

echo "[4/4] Building overlay MBTiles with tippecanoe..."
tippecanoe \
    -o "${MBTILES}" \
    --force \
    --name "OS Open Zoomstack Overlay" \
    --attribution "Contains OS data © Crown copyright and database right" \
    --minimum-zoom 6 \
    --maximum-zoom 14 \
    --drop-densest-as-needed \
    --extend-zooms-if-still-dropping \
    -L roads:"${TMPDIR}/roads.geojson" \
    -L woodland:"${TMPDIR}/woodland.geojson" \
    -L water:"${TMPDIR}/water.geojson"

rm -rf "${TMPDIR}"

echo "Done → ${MBTILES}"
echo "Size: $(du -h "${MBTILES}" | cut -f1)"
echo ""
echo "Copy to your Cairn node:"
echo "  scp ${MBTILES} cairn:/opt/cairn/tiles/"
