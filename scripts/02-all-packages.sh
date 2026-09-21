#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/toolchain.sh"
BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
export BUNDLE_DIR

# This is the all-groups entry point: the TUI's "Install packages" step and
# 08-build-shell.sh's update path both want every group at once. A partial
# install calls a distro's packages.sh directly with PACKAGE_GROUP set.
export PACKAGE_GROUP="all"
export BASE_DISTRO="$(detect_base_distro)"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    bash "$BUNDLE_DIR/installer/distro/arch/packages.sh"
elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    bash "$BUNDLE_DIR/installer/distro/fedora/packages.sh"
elif [[ "$BASE_DISTRO" == "debian" ]]; then
    bash "$BUNDLE_DIR/installer/distro/debian/packages.sh"
else
    die "BASE_DISTRO must be 'arch', 'fedora', or 'debian' (got '${BASE_DISTRO}')"
fi
