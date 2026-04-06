#!/bin/bash
set -euo pipefail

# Build UK Government Emergency Preparedness ZIM using Zimit
# Requires: Docker
# Output:   ./output/govuk-prepare.zim

OUTDIR="$(cd "$(dirname "$0")" && pwd)/output"
mkdir -p "${OUTDIR}"

docker run --rm -v "${OUTDIR}:/output" \
    ghcr.io/openzim/zimit:latest \
    zimit \
    --seeds "https://prepare.campaign.gov.uk/" \
    --collection "govuk-prepare" \
    --title "UK Government Emergency Preparedness" \
    --description "Official UK government guidance on preparing for emergencies" \
    --lang eng \
    --scopeType "page" \
    -w 2 \
    --waitUntil "load" \
    --behaviors "" \
    --limit 0

echo "Done → ${OUTDIR}/govuk-prepare.zim"
