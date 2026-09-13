#!/usr/bin/env bash
# install-kind.sh - Which half of an install a run is doing.
#
# Two things install Caelestia: a checkout, through `install.sh` and the installer
# TUI, and a package, through `caelestia install` afterwards. The line between them
# is ownership - a package owns every file under /usr and /etc, including the ones
# an older installer wrote there (the SDDM theme, its sudoers drop-in, the KWin
# effect). So a package's run must not write any of them, and the scripts that
# otherwise would are told so here rather than guessing from what they find.
#
#   CAELESTIA_INSTALL_KIND=source|package   set by the front end running the steps
#   install_kind                            prints which one this run is
#   install_is_packaged                     true when a package owns the files
#
# With nothing set the answer comes from where this library sits: a checkout's
# scripts are under the user's home, a package's are under /usr. That keeps a step
# script run by hand honest about which install it belongs to.
#
# The step scripts stay the one implementation of both halves (that is what
# parity-6 decided): this only tells them which of their own sections apply.
if [[ -z "${CAELESTIA_INSTALL_KIND_SOURCED:-}" ]]; then
CAELESTIA_INSTALL_KIND_SOURCED=1

install_kind() {
    case "${CAELESTIA_INSTALL_KIND:-}" in
        source | package)
            printf '%s\n' "$CAELESTIA_INSTALL_KIND"
            return 0
            ;;
    esac

    local lib_dir
    lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    case "$lib_dir" in
        /usr/*) printf 'package\n' ;;
        *) printf 'source\n' ;;
    esac
}

install_is_packaged() {
    [[ "$(install_kind)" == "package" ]]
}

fi
