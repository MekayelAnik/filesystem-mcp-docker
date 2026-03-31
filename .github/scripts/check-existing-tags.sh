#!/usr/bin/env bash
set -euo pipefail

FORCE_BUILD="${FORCE_BUILD:-false}"
GHCR_REPO="${GHCR_REPO:-}"
VERSION="${VERSION:-}"

if [[ -z "$GHCR_REPO" || -z "$VERSION" ]]; then
    echo "Missing required inputs. Expected GHCR_REPO and VERSION" >&2
    exit 1
fi

if [[ "$FORCE_BUILD" == "true" ]]; then
    echo "skip_build=false"
    exit 0
fi

# HEAD-only digest check via crane (single HTTP HEAD request, no manifest body download)
# Falls back to docker manifest inspect if crane is not available
if command -v crane >/dev/null 2>&1; then
    if crane digest "${GHCR_REPO}:${VERSION}" >/dev/null 2>&1; then
        echo "Image version already present in GHCR (crane HEAD check); skipping build"
        echo "skip_build=true"
        exit 0
    fi
else
    if docker manifest inspect "${GHCR_REPO}:${VERSION}" >/dev/null 2>&1; then
        echo "Image version already present in GHCR; skipping build"
        echo "skip_build=true"
        exit 0
    fi
fi

echo "Image version not found in GHCR; building"
echo "skip_build=false"
