#!/usr/bin/env bash
# install-kind.sh - Which half of an install a run is doing, and where that half's files
# are.
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
#
# The same split decides where each kind keeps its files, and the functions below that
# answer that are the only place the layout is written down. `src/bin/caelestia` sources
# this file for them as well, so the command and the steps cannot drift apart.
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

# Where that half keeps its files.
#
# This is the one definition of the layout, and everything that needs a path asks for it:
# the steps that write the session environment, the autostart wrapper that repeats those
# paths, and the command itself, which used to carry their checkout form unconditionally -
# so on a packaged machine the command put ~/.config/quickshell/caelestia ahead of
# /etc/xdg/quickshell/caelestia for everything it spawned, and a leftover tree from an old
# checkout would have won over the one the package installed.
#
# Named functions rather than one lookup keyed on a string: the callers want five different
# things, and a name says which.
# The palette's templates and named schemes.
install_lib_dir() {
    if install_is_packaged; then
        printf '%s\n' /usr/lib/caelestia
    else
        printf '%s\n' "$HOME/.local/lib/caelestia"
    fi
}

# Where the helper commands live.
install_bin_dir() {
    if install_is_packaged; then
        printf '%s\n' /usr/bin
    else
        printf '%s\n' "$HOME/.local/bin"
    fi
}

# What QML2_IMPORT_PATH has to contain for the shell to find its own tree and the plugin
# modules in it. The two entries are the ones that differ between the install kinds.
install_qml_import_path() {
    if install_is_packaged; then
        printf '%s\n' "/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia"
    else
        printf '%s\n' "$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"
    fi
}

# The shell's entrypoint, which is what the autostart unit runs.
install_shell_config() {
    if install_is_packaged; then
        printf '%s\n' /etc/xdg/quickshell/caelestia/shell.qml
    else
        printf '%s\n' "$HOME/.config/quickshell/caelestia/shell.qml"
    fi
}

# The shell's assets, which sit beside the entrypoint: fonts, icons, sounds and the
# rest of what it draws with. A package ships the small ones and leaves the fonts to
# the install, so 12-fetch-assets.sh needs to know where the tree is; Fonts.qml looks
# in the user's own directory as well, which is where that step puts them.
install_assets_dir() {
    printf '%s\n' "$(dirname -- "$(install_shell_config)")/assets"
}

fi
