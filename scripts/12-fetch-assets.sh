#!/usr/bin/env bash
# 12-fetch-assets.sh  Download the shell's bundled fonts when the install does not
#                     ship them, into the user's own asset directory.
#
# The package leaves the fonts out on purpose. They are 309 MiB of the 401 MiB it would
# otherwise install - 47 SF Pro files, of which the shell names two families - and
# upstream's package does not carry fonts at all: it takes four font packages as
# dependencies. 02-packages handles the font packages this port needs; this step is for
# the one family no repository has.
#
# They cannot go in the shell's tree on a packaged install. That tree belongs to the
# package, so a download there would leave ~300 MiB behind that `pacman -R` does not
# know about, which is the state this branch exists to stop creating. They go in
# $XDG_DATA_HOME/caelestia/assets/fonts instead, and shell/modules/Fonts.qml loads
# every font under both directories.
#
# Best-effort: the shell runs with a system font, so a machine with no network, no git
# or a tag that has not been pushed keeps a working shell and a warning. Re-run
# `caelestia install` to try again.
#
# ci:allow-no-strict-mode - every failure below is handled and exits 0, because failing
# here would abort an install that is otherwise fine.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/install-kind.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

ASSETS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/assets"
FONTS_DIR="$ASSETS_DIR/fonts"
SHELL_FONTS="$(install_assets_dir)/fonts"

# The project and the ref the payload comes from. The defaults are what a packaged
# install uses; both are overridable so the step can be tested against a local checkout
# instead of the network.
REPO="${CAELESTIA_ASSETS_REPO:-https://github.com/ladybug-me/caelestia-kde}"

# True when a directory holds a font at its top two levels (SF-Pro/SF-Pro.ttf is two).
has_fonts() {
    [[ -n "$(find "$1" -maxdepth 2 \( -name '*.ttf' -o -name '*.otf' \) -print -quit 2>/dev/null)" ]]
}

# Already in the tree: every checkout install, whose fonts arrived with the source it
# built. The package's tree has none, which is what this step is for.
if has_fonts "$SHELL_FONTS"; then
    ok "Fonts are part of this install's tree."
    exit 0
fi

# Idempotent. The copy below is atomic enough for this: a populated directory means a
# previous run finished, and a partial one is not possible because the fonts are copied
# from a completed checkout.
if has_fonts "$FONTS_DIR"; then
    ok "Fonts already downloaded to $FONTS_DIR"
    exit 0
fi

if [[ "${CAELESTIA_SKIP_ASSETS:-}" == "1" ]]; then
    skip "Skipping the font download (CAELESTIA_SKIP_ASSETS=1)."
    exit 0
fi

# A machine that already has the family installed, by a font package or by hand, has
# nothing to gain from 150 MiB of download: the shell asks for the family by name.
if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi 'SF Pro'; then
    ok "SF Pro is already installed on this machine."
    exit 0
fi

if ! command -v git >/dev/null 2>&1; then
    warn "git is not installed, so the fonts cannot be downloaded; the shell will use a system font."
    exit 0
fi

# The tag the package was built from: the same compiled helper `caelestia version` reads,
# so there is no second source of truth for the version. `CAELESTIA_ASSETS_REF` takes the
# same `tag=` / `branch=` vocabulary the PKGBUILD's own `_ref` does, and a bare ref name.
if [[ -n "${CAELESTIA_ASSETS_REF:-}" ]]; then
    GIT_REF="${CAELESTIA_ASSETS_REF#tag=}"
    GIT_REF="${GIT_REF#branch=}"
else
    version="$("$(install_lib_dir)/version" -s 2>/dev/null | awk '{ sub(/,/, "", $2); print $2 }')"
    if [[ -z "$version" ]]; then
        warn "Could not tell which version to download the fonts from; set CAELESTIA_ASSETS_REF to fetch them."
        exit 0
    fi
    GIT_REF="v$version"
fi

info "Downloading the bundled fonts (about 150 MiB, once)..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# A partial clone of just the font directory: blob:none defers the file contents and the
# sparse checkout only asks for this one path, so the download is the fonts rather than
# the whole repository. 03a-wallpapers.sh fetches its pack the same way.
if ! git clone --depth 1 --filter=blob:none --sparse "$REPO" "$TMP_DIR/repo" >/dev/null 2>&1; then
    warn "Could not clone $REPO for the fonts; the shell will use a system font. Re-run 'caelestia install' to try again."
    exit 0
fi

if ! git -C "$TMP_DIR/repo" fetch --depth 1 origin "$GIT_REF" >/dev/null 2>&1 ||
    ! git -C "$TMP_DIR/repo" checkout --detach FETCH_HEAD >/dev/null 2>&1; then
    warn "$REPO has no '$GIT_REF'; the shell will use a system font."
    exit 0
fi

if ! git -C "$TMP_DIR/repo" sparse-checkout set shell/assets/fonts >/dev/null 2>&1; then
    warn "Could not check the fonts out of $GIT_REF; the shell will use a system font."
    exit 0
fi

if [[ ! -d "$TMP_DIR/repo/shell/assets/fonts" ]]; then
    warn "$GIT_REF has no shell/assets/fonts to copy."
    exit 0
fi

mkdir -p "$FONTS_DIR"
cp -a "$TMP_DIR/repo/shell/assets/fonts/." "$FONTS_DIR/" || {
    warn "Could not copy the fonts into $FONTS_DIR."
    exit 0
}

ok "Fonts installed into $FONTS_DIR"
