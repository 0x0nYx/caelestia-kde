#!/usr/bin/env bash
if [[ -z "${CAELESTIA_DOWNLOAD_SOURCED:-}" ]]; then
CAELESTIA_DOWNLOAD_SOURCED=1

file_sha256() {
    sha256sum "$1" | cut -d' ' -f1
}

fetch_asset() {
    local url="$1" dest="$2"
    shift 2
    curl -fsSL --connect-timeout 10 "$@" "$url" -o "$dest"
}

# 0 when the artifact matches the checksum published beside it, 1 when it does not
# match, 2 when the release publishes none. What that means for the artifact is the
# caller's decision: an executable has to match, an archive may be allowed through
# with a warning.
verify_download() {
    local url="$1" file="$2" sidecar expected
    sidecar="$(mktemp)"
    if ! fetch_asset "$url.sha256" "$sidecar" 2>/dev/null; then
        rm -f "$sidecar"
        return 2
    fi
    expected="$(cut -d' ' -f1 < "$sidecar")"
    rm -f "$sidecar"
    [[ -n "$expected" ]] || return 2
    [[ "$expected" == "$(file_sha256 "$file")" ]]
}

fi
