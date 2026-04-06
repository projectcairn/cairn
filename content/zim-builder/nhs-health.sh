#!/bin/bash
set -euo pipefail

# Build NHS Health A-Z ZIM file using Zimit (Browsertrix-based crawler)
# Requires: Docker
# Output:   ./output/nhs-health-az.zim

OUTDIR="$(cd "$(dirname "$0")" && pwd)/output"
mkdir -p "${OUTDIR}"

docker run --rm -v "${OUTDIR}:/output" \
    ghcr.io/openzim/zimit:latest \
    zimit \
    --seeds "https://www.nhs.uk/conditions/" \
    --name "nhs-health-az" \
    --title "NHS Health A-Z" \
    --description "NHS health conditions and first aid and mental health and wellbeing guides" \
    --lang eng \
    --scopeType "prefix" \
    --scopeIncludeRx "https://www\.nhs\.uk/conditions/" \
    --scopeIncludeRx "https://www\.nhs\.uk/live-well/" \
    --scopeIncludeRx "https://www\.nhs\.uk/mental-health/" \
    --scopeIncludeRx "https://www\.nhs\.uk/common-health-questions/accidents-first-aid-and-treatments/" \
    -w 4 \
    --waitUntil "load"

echo "Done → ${OUTDIR}/nhs-health-az.zim"
