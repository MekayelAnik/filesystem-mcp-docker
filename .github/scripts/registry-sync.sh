#!/usr/bin/env bash
set -euo pipefail

DOCKERHUB_REPO="${DOCKERHUB_REPO:-}"
GHCR_REPO="${GHCR_REPO:-}"
TAGS="${TAGS:-}"

if [[ -z "$DOCKERHUB_REPO" || -z "$GHCR_REPO" || -z "$TAGS" ]]; then
    echo "Missing required inputs. Expected DOCKERHUB_REPO, GHCR_REPO, TAGS" >&2
    exit 1
fi

# --- Shared retry helpers ---
# shellcheck source=lib-retry.sh
source "$(dirname "$0")/lib-retry.sh"

# --- Inspect cache: each ref inspected at most once ---

declare -A INSPECT_CACHE
declare -A INSPECT_CACHE_RC

cached_inspect() {
    local ref="$1"

    if [[ -n "${INSPECT_CACHE_RC[$ref]+x}" ]]; then
        if [[ "${INSPECT_CACHE_RC[$ref]}" -ne 0 ]]; then
            return "${INSPECT_CACHE_RC[$ref]}"
        fi
        printf '%s' "${INSPECT_CACHE[$ref]}"
        return 0
    fi

    local out="" rc=0
    set +e
    out="$(docker buildx imagetools inspect "$ref" 2>/dev/null)"
    rc=$?
    set -e

    INSPECT_CACHE_RC["$ref"]=$rc
    if [[ "$rc" -eq 0 ]]; then
        INSPECT_CACHE["$ref"]="$out"
        printf '%s' "$out"
    fi
    return "$rc"
}

invalidate_cache() {
    local ref="$1"
    unset 'INSPECT_CACHE['"$ref"']' 2>/dev/null || true
    unset 'INSPECT_CACHE_RC['"$ref"']' 2>/dev/null || true
}

tag_exists() {
    local ref="$1"
    cached_inspect "$ref" >/dev/null 2>&1
}

get_platform_set() {
    local ref="$1"
    local inspect_text
    local rc

    set +e
    inspect_text="$(cached_inspect "$ref")"
    rc=$?
    set -e

    if [[ "$rc" -ne 0 ]]; then
        return "$rc"
    fi

    echo "$inspect_text" | awk '/Platform:/{print $2}' | sort -u | tr '\n' ',' | sed 's/,$//'
}

sync_tag() {
    local tag="$1"
    local dh_ref="${DOCKERHUB_REPO}:${tag}"
    local ghcr_ref="${GHCR_REPO}:${tag}"

    local dh_exists="no"
    local ghcr_exists="no"

    if tag_exists "$ghcr_ref"; then
        ghcr_exists="yes"
    fi

    if tag_exists "$dh_ref"; then
        dh_exists="yes"
    fi

    if [[ "$ghcr_exists" == "no" && "$dh_exists" == "yes" ]]; then
        echo "Syncing $tag: Docker Hub -> GHCR (backfill mode)"
        set +e
        run_with_retry "sync ${tag} dockerhub->ghcr" docker buildx imagetools create -t "$ghcr_ref" "$dh_ref" >/dev/null
        create_rc=$?
        set -e

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag backfill due to Docker Hub rate limiting" >&2
            return 0
        fi
        if [[ "$create_rc" -ne 0 ]]; then
            return "$create_rc"
        fi
        invalidate_cache "$ghcr_ref"
    elif [[ "$ghcr_exists" == "no" && "$dh_exists" == "no" ]]; then
        echo "Tag $tag: not found in either registry - skipping"
        return 0
    elif [[ "$ghcr_exists" == "yes" && "$dh_exists" == "no" ]]; then
        echo "Syncing $tag: GHCR -> Docker Hub"
        set +e
        run_with_retry "sync ${tag} ghcr->dockerhub" docker buildx imagetools create -t "$dh_ref" "$ghcr_ref" >/dev/null
        create_rc=$?
        set -e

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag mirror push due to Docker Hub rate limiting" >&2
            return 0
        fi
        if [[ "$create_rc" -ne 0 ]]; then
            return "$create_rc"
        fi
        invalidate_cache "$dh_ref"
    else
        # Both exist — check platform parity using cached inspect data
        local ghcr_platforms dh_platforms
        set +e
        ghcr_platforms="$(get_platform_set "$ghcr_ref")"
        ghcr_rc=$?
        set -e
        if [[ "$ghcr_rc" -ne 0 ]]; then
            echo "::error::Failed to inspect GHCR platforms for $tag" >&2
            return 1
        fi

        set +e
        dh_platforms="$(get_platform_set "$dh_ref")"
        dh_rc=$?
        set -e
        if [[ "$dh_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag sync parity check due to Docker Hub rate limiting" >&2
            return 0
        fi
        if [[ "$dh_rc" -ne 0 ]]; then
            echo "::error::Failed to inspect Docker Hub platforms for $tag" >&2
            return 1
        fi

        if [[ -n "$ghcr_platforms" && -n "$dh_platforms" && "$ghcr_platforms" == "$dh_platforms" ]]; then
            echo "Tag $tag: platform manifests already match across registries - skipping"
            return 0
        fi

        echo "Syncing $tag: mismatch detected, GHCR -> Docker Hub"
        set +e
        run_with_retry "sync ${tag} mismatch ghcr->dockerhub" docker buildx imagetools create -t "$dh_ref" "$ghcr_ref" >/dev/null
        create_rc=$?
        set -e

        if [[ "$create_rc" -eq 2 ]]; then
            echo "::warning::Skipping tag $tag mismatch sync due to Docker Hub rate limiting" >&2
            return 0
        fi
        if [[ "$create_rc" -ne 0 ]]; then
            return "$create_rc"
        fi
        invalidate_cache "$dh_ref"
    fi

    # Post-sync: trust imagetools create exit code — no re-verification needed.
    # imagetools create is an atomic manifest-level copy; success guarantees parity.
    echo "Synced $tag successfully"
    return 0
}

IFS=',' read -ra TAG_ARRAY <<< "$TAGS"
declare -A SEEN_TAGS

for tag in "${TAG_ARRAY[@]}"; do
    clean_tag="$(echo "$tag" | xargs)"
    if [[ -z "$clean_tag" ]]; then
        continue
    fi

    echo "Processing tag: $clean_tag"

    if [[ -n "${SEEN_TAGS[$clean_tag]:-}" ]]; then
        echo "Tag $clean_tag: duplicate in input list - skipping duplicate"
        continue
    fi

    SEEN_TAGS[$clean_tag]=1
    sync_tag "$clean_tag"
done
