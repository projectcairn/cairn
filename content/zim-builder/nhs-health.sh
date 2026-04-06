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
    --url "https://www.nhs.uk/conditions/" \
    --name "nhs-health-az" \
    --title "NHS Health A-Z" \
    --description "NHS health conditions, first aid, mental health and wellbeing guides" \
    --creator "Project Cairn (content from NHS.uk under OGL)" \
    --lang eng \
    --output "/output/nhs-health-az.zim" \
    --scopeType "prefix" \
    --include "https://www.nhs.uk/conditions/" \
    --include "https://www.nhs.uk/live-well/" \
    --include "https://www.nhs.uk/mental-health/" \
    --include "https://www.nhs.uk/common-health-questions/accidents-first-aid-and-treatments/" \
    --workers 4 \
    --waitUntil "load" \
    --behaviors "" \
    --limit 0

echo "Done → ${OUTDIR}/nhs-health-az.zim"
