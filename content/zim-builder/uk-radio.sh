#!/bin/bash
set -euo pipefail

# Build UK Radio Reference ZIM from generated static HTML
# Requires: python3, zimwriterfs (from zim-tools)
# Output:   ./output/uk-radio-reference.zim

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${SCRIPT_DIR}/output"
HTML_DIR="${OUTDIR}/radio-html"

echo "=== UK Radio Reference ZIM Builder ==="

echo "[1/2] Generating HTML pages..."
python3 "${SCRIPT_DIR}/build-radio-html.py"

if [ ! -f "${HTML_DIR}/index.html" ]; then
    echo "ERROR: HTML generation failed — no index.html found"
    exit 1
fi

echo "[2/2] Packaging into ZIM..."
if command -v zimwriterfs &>/dev/null; then
    zimwriterfs \
        --welcome "index.html" \
        --illustration "favicon.png" \
        --name "uk-radio-reference" \
        --title "UK Radio Reference" \
        --description "PMR446, emergency, amateur, marine and mesh radio quick reference for the UK" \
        --creator "Project Cairn" \
        --publisher "Project Cairn" \
        --language "eng" \
        "${HTML_DIR}" \
        "${OUTDIR}/uk-radio-reference.zim"
    echo "Done → ${OUTDIR}/uk-radio-reference.zim"
else
    echo "WARNING: zimwriterfs not found. Install zim-tools:"
    echo "  sudo apt install zim-tools"
    echo "HTML output is ready at ${HTML_DIR}/"
    echo "Run this script again after installing zim-tools to create the ZIM file."
fi
