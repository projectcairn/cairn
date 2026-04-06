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
    --name "govuk-prepare" \
    --title "UK Emergency Preparedness" \
    --description "Official UK government guidance on preparing for emergencies" \
    --lang en \
    --scopeType "page" \
    -w 2 \
    --waitUntil "load"

echo "Done → ${OUTDIR}/govuk-prepare.zim"
