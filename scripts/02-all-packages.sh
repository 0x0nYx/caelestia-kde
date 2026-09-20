#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/toolchain.sh"
BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export BUNDLE_DIR
export PACKAGE_GROUP="${PACKAGE_GROUP:-all}"
BASE_DISTRO="${BASE_DISTRO:-$(detect_base_distro)}"
export BASE_DISTRO
if [[ "$BASE_DISTRO" == "arch" ]]; then
    bash "$BUNDLE_DIR/installer/distro/arch/packages.sh"
elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    bash "$BUNDLE_DIR/installer/distro/fedora/packages.sh"
elif [[ "$BASE_DISTRO" == "debian" ]]; then
    bash "$BUNDLE_DIR/installer/distro/debian/packages.sh"
else
    die "BASE_DISTRO must be 'arch', 'fedora', or 'debian' (got '${BASE_DISTRO}')"
fi
