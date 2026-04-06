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
    --url "https://pfaf.org/user/Plant.aspx" \
    --name "pfaf-plants" \
    --title "Plants For A Future — Edible & Medicinal Plants" \
    --description "Database of edible and medicinal plants with cultivation details" \
    --creator "Project Cairn (PFAF content under CC-BY-SA 4.0)" \
    --lang eng \
    --output "/output" \
    --scopeType "prefix" \
    --include "https://pfaf.org/user/Plant.aspx" \
    --include "https://pfaf.org/user/DatabaseSearhResult.aspx" \
    --workers 4 \
    --waitUntil "load" \
    --behaviors "" \
    --limit 0

echo "Done → ${OUTDIR}/pfaf-plants.zim"
