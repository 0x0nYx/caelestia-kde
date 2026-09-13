#!/usr/bin/env bash
# test_autostart_unit.sh - Tests for the one mechanism that starts the shell.
#
# parity-6 decided the shell starts from a single systemd user unit, enabled once by
# `caelestia install`, instead of from a desktop entry that KDE's xdg-autostart
# generator turns into a second unit of its own. These tests read the files that
# have to agree on that: the unit name, who writes it, who restarts it, who removes
# it, and the package that ships the other copy of it.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOSTART_SCRIPT="$REPO_ROOT/scripts/10-autostart.sh"
RESTART_SCRIPT="$REPO_ROOT/shell/scripts/restart_shell.sh"
UNINSTALL_SCRIPT="$REPO_ROOT/uninstall.sh"
IPC="$REPO_ROOT/src/bin/caelestia-shell-ipc"
PKGBUILD="$REPO_ROOT/packaging/aur/caelestia-shell-kde/PKGBUILD"
PACKAGED_UNIT="$REPO_ROOT/packaging/aur/caelestia-shell-kde/caelestia-shell.service"

test_the_checkout_writes_the_unit_instead_of_an_entry() {
    local script
    script="$(cat "$AUTOSTART_SCRIPT")"

    assert_contains "$script" 'config/systemd/user/caelestia-shell.service' "the checkout's install should write the shell's unit"
    assert_contains "$script" 'ExecStart=%h/.local/bin/caelestia-autostart.sh' "and the unit should run the wrapper that sets the environment"
    assert_contains "$script" 'systemctl --user enable caelestia-shell.service' "and enable it, so it starts on the next login"

    # The entry's writer is gone. The comment above still names it, and the KWin
    # interface entry further down is a different file that has to stay - it is how
    # KWin decides whether to offer the screencast protocol.
    assert_not_contains "$script" 'AUTOSTART_DIR/caelestiashell.desktop" << EOF' "it must not write the retired autostart entry"
    assert_contains "$script" 'applications/quickshell.desktop' "while the KWin interface entry it writes stays"
}

test_an_older_entry_and_its_generated_unit_are_retired() {
    local script
    script="$(cat "$AUTOSTART_SCRIPT")"

    assert_contains "$script" 'AUTOSTART_DIR/caelestiashell.desktop' "an install that still has the old entry should have it removed"
    assert_contains "$script" 'disable app-caelestiashell@autostart.service' "and the unit the generator made from it disabled"
}

test_the_ordering_the_entry_phase_provided_is_kept() {
    # The shell registers org.freedesktop.Notifications and applications decide once,
    # at startup, whether a notification server exists. The entry bought that with
    # X-KDE-AutostartPhase=1; the unit buys it with an ordering against the target
    # the same generator puts the app units in.
    assert_contains "$(cat "$AUTOSTART_SCRIPT")" 'Before=xdg-desktop-autostart.target' "the checkout's unit should keep the apps behind it"
    assert_contains "$(cat "$PACKAGED_UNIT")" 'Before=xdg-desktop-autostart.target' "and so should the package's"
}

test_the_wrapper_names_the_paths_of_the_install_it_is_part_of() {
    # A packaged install runs the shell from /etc/xdg with the plugin and the palette
    # data in /usr, and the environment file 08-build-shell.sh writes names those paths.
    # The wrapper used to name the checkout's paths unconditionally, which on a packaged
    # machine both failed the entrypoint check - nothing to autostart, so the unit was
    # never enabled - and would have dropped /usr/lib/qt6/qml from QML2_IMPORT_PATH,
    # where the Caelestia plugin modules are.
    local script
    script="$(cat "$AUTOSTART_SCRIPT")"

    assert_contains "$script" 'install_is_packaged' "the autostart step has to know which install it is part of"
    assert_contains "$script" 'SHELL_CONFIG="/etc/xdg/quickshell/caelestia/shell.qml"' "a packaged install should autostart the tree the package installed"
    assert_contains "$script" 'export QML2_IMPORT_PATH="/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia"' "and the wrapper should keep the package's QML import path"
    assert_contains "$script" 'export CAELESTIA_LIB_DIR="/usr/lib/caelestia"' "and the package's library directory"
    assert_contains "$script" 'export CAELESTIA_BIN_DIR="/usr/bin"' "and the package's command directory"

    # The checkout's own paths have to survive: this is the same script for both.
    assert_contains "$script" 'export PATH="$HOME/.local/bin:$PATH"' "a checkout should still put its own bin directory on the shell's PATH"
    assert_contains "$script" 'export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"' "and keep its own QML import path"
    assert_contains "$script" 'export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"' "and its own library directory"
    assert_contains "$script" 'exec "$QUICKSHELL_PATH" -n -p "$SHELL_ENTRYPOINT"' "the wrapper should take the entrypoint from the install kind, not a fixed path"
    assert_not_contains "$script" 'exec "$QUICKSHELL_PATH" -n -p "$HOME/.config/quickshell/caelestia/shell.qml"' "the entrypoint must not be the checkout's on every machine"
}

test_restarting_goes_through_that_unit() {
    local script
    script="$(cat "$RESTART_SCRIPT")"

    assert_contains "$script" 'systemctl --user restart caelestia-shell.service' "the shell's restart action should restart the login unit"
    assert_not_contains "$script" 'restart app-caelestiashell@autostart.service' "and not the unit the retired entry generated"
}

test_uninstall_removes_and_disables_the_unit() {
    local script
    script="$(cat "$UNINSTALL_SCRIPT")"

    assert_contains "$script" 'disable --now caelestia-shell.service' "the unit should be stopped and disabled before its file goes"
    assert_contains "$script" 'rm -f "$USER_SYSTEMD/caelestia-shell.service"' "and removed"
    assert_contains "$script" 'disable app-caelestiashell@autostart.service' "the retired generated unit should be disabled too"
}

test_the_package_ships_the_unit_and_not_an_entry() {
    local pkgbuild
    pkgbuild="$(cat "$PKGBUILD")"

    assert_contains "$pkgbuild" 'usr/lib/systemd/user/caelestia-shell.service' "the package should install the unit"
    assert_not_contains "$pkgbuild" '$pkgdir/etc/xdg/autostart' "and must not install an autostart entry beside it"
    assert_contains "$(cat "$PACKAGED_UNIT")" 'ExecStart=/usr/bin/caelestia-autostart' "the package's unit should run the package's wrapper"
}

test_the_ipc_start_helper_does_not_take_the_login_units_name() {
    # `caelestia shell` starts a transient unit when no shell is running. A transient
    # unit cannot take a name a loaded unit already has, so it must not be called
    # caelestia-shell while caelestia-shell.service exists.
    local ipc
    ipc="$(cat "$IPC")"

    assert_contains "$ipc" '--unit="caelestia-shell-start"' "the transient start helper should use a name of its own"
    assert_not_contains "$ipc" '--unit="caelestia-shell"' "and not the login unit's"
}

run_tests
