#!/bin/bash
set -euo pipefail

# Build Plants For A Future ZIM using Zimit
# Requires: Docker
# Output:   ./output/pfaf-plants.zim

OUTDIR="$(cd "$(dirname "$0")" && pwd)/output"
mkdir -p "${OUTDIR}"

docker run --rm -v "${OUTDIR}:/output" \
    ghcr.io/openzim/zimit:latest \
    zimit \
    --seeds "https://pfaf.org/user/Plant.aspx" \
    --name "pfaf-plants" \
    --collection "pfaf-plants" \
    --title "Plants For A Future — Edible & Medicinal Plants" \
    --description "Database of edible and medicinal plants with cultivation details" \
    --lang eng \
    --scopeType "prefix" \
    --scopeIncludeRx "pfaf\.org/user/Plant\.aspx" \
    --scopeIncludeRx "pfaf\.org/user/DatabaseSearhResult\.aspx" \
    -w 4 \
    --waitUntil "load" \
    --behaviors ""

echo "Done → ${OUTDIR}/pfaf-plants.zim"
