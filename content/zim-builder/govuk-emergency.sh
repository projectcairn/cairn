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
    --url "https://prepare.campaign.gov.uk/" \
    --name "govuk-prepare" \
    --title "UK Government Emergency Preparedness" \
    --description "Official UK government guidance on preparing for emergencies" \
    --creator "Project Cairn (content under OGL v3.0)" \
    --lang eng \
    --output "/output/govuk-prepare.zim" \
    --scopeType "page" \
    --workers 2 \
    --waitUntil "load" \
    --behaviors "" \
    --limit 0

echo "Done → ${OUTDIR}/govuk-prepare.zim"
