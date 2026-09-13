#!/usr/bin/env bash
# test_install_paths.sh - Tests for the one definition of where an install keeps its files.
#
# The layout used to be written out in three places: the wrapper the autostart step
# generates, the environment the build step writes, and the command's own header. The
# command's copy was the checkout's unconditionally, so on a packaged machine it put
# ~/.config/quickshell/caelestia ahead of the package's tree for everything it spawned,
# and a leftover checkout would have won over the package. These tests run the library
# that owns the layout now, and the command, for both kinds.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/install-kind.sh"
CLI="$REPO_ROOT/src/bin/caelestia"

# layout <kind> <function>: what that function answers for that kind of install.
layout() {
    CAELESTIA_INSTALL_KIND="$1" BUNDLE_DIR="$REPO_ROOT" LAYOUT_LIB="$LIB" LAYOUT_FN="$2" \
        bash -c '
            set -u
            source "$LAYOUT_LIB"
            "$LAYOUT_FN"
        '
}

# cli_env <bin dir> <home>: what the command exports for everything it spawns, decided
# from where the command is - which is the whole of the inference it does.
#
# The command is sourced with its path in $0 and nothing in $@, because a sourced script
# inherits the caller's positional parameters and this one ends by calling main "$@": with
# an argument in $@ it would run that as a subcommand and exit. stdout is silenced so the
# usage text it prints does not become the answer.
cli_env() {
    env -u QML2_IMPORT_PATH -u CAELESTIA_LIB_DIR -u CAELESTIA_INSTALL_KIND \
        HOME="$2" XDG_CONFIG_HOME="$2/.config" CAELESTIA_BIN_DIR="$1" \
        bash -c 'source "$0" >/dev/null 2>&1; printf "%s|%s" "$QML2_IMPORT_PATH" "$CAELESTIA_LIB_DIR"' \
        "$CLI"
}

test_the_packaged_layout_is_the_packages_directories() {
    assert_eq "/etc/xdg/quickshell/caelestia/shell.qml" "$(layout package install_shell_config)" "the shell tree"
    assert_eq "/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia" "$(layout package install_qml_import_path)" "the QML import path"
    assert_eq "/usr/lib/caelestia" "$(layout package install_lib_dir)" "the library directory"
    assert_eq "/usr/bin" "$(layout package install_bin_dir)" "the command directory"
    assert_eq "/usr/share/caelestia" "$(layout package install_data_dir)" "the data directory"
    assert_eq "/usr/share/caelestia/version.env" "$(layout package install_version_file)" "the version file"
}

test_the_checkout_layout_is_the_users_own_directories() {
    assert_eq "$HOME/.config/quickshell/caelestia/shell.qml" "$(layout source install_shell_config)" "the shell tree"
    assert_eq "$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia" "$(layout source install_qml_import_path)" "the QML import path"
    assert_eq "$HOME/.local/lib/caelestia" "$(layout source install_lib_dir)" "the library directory"
    assert_eq "$HOME/.local/bin" "$(layout source install_bin_dir)" "the command directory"
    assert_eq "$REPO_ROOT" "$(layout source install_data_dir)" "the data directory is the checkout"
    assert_eq "$REPO_ROOT/.github/version.env" "$(layout source install_version_file)" "the version file"
}

test_no_path_is_the_same_in_both_layouts() {
    # A copy-paste that left the checkout's value in the package's branch would silently
    # point a package at a directory it never creates.
    local fn
    for fn in install_shell_config install_qml_import_path install_lib_dir install_bin_dir install_data_dir install_version_file; do
        assert_ne "$(layout source "$fn")" "$(layout package "$fn")" "$fn should differ between the two installs"
    done
}

test_the_kind_can_be_stated_rather_than_inferred() {
    # The front end that runs the steps says which half they are, and the answer has to
    # win over where the library happens to sit.
    assert_eq "package" "$(layout package install_kind)" "the environment's answer wins"
    assert_eq "source" "$(layout source install_kind)" "in both directions"
}

test_the_command_names_the_installs_own_directories() {
    # The bug this replaced: the command exported the checkout's paths on every machine,
    # so a packaged install spawned its shell with ~/.config/quickshell/caelestia ahead of
    # /etc/xdg/quickshell/caelestia, and /usr/lib/qt6/qml was lost from the import path.
    assert_eq "/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia|/usr/lib/caelestia" \
        "$(cli_env /usr/bin "$HOME")" "a command in /usr/bin belongs to a package"

    local home out
    home="$(new_tmpdir)/home"
    out="$(cli_env "$home/.local/bin" "$home")"
    assert_eq "$home/.local/lib/qt6/qml:$home/.config/quickshell/caelestia|$home/.local/lib/caelestia" \
        "$out" "and one anywhere else belongs to a checkout, from that user's home"
}

test_the_command_prefers_what_the_session_told_it() {
    # A session gets these from ~/.config/environment.d, written for the install it
    # belongs to. They are what the command appends to, not what it overrides.
    local dir
    dir="$(new_tmpdir)"
    local out
    out="$(env HOME="$dir/home" XDG_CONFIG_HOME="$dir/home/.config" CAELESTIA_BIN_DIR=/usr/bin \
        QML2_IMPORT_PATH=/from/the/session CAELESTIA_LIB_DIR=/from/the/session \
        bash -c 'source "$0" >/dev/null 2>&1; printf "%s|%s" "$QML2_IMPORT_PATH" "$CAELESTIA_LIB_DIR"' \
        "$CLI")"

    assert_eq "/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia:/from/the/session|/from/the/session" \
        "$out" "the session's values should survive"
}

test_a_package_reports_the_version_it_was_installed_as() {
    # Upgrading the package without rerunning `caelestia install` leaves the copy
    # 08-build-shell.sh recorded behind, and the command used to report that instead of
    # the package it is actually running from. A checkout is the other way round: its
    # record is what was installed, and the tree can have moved on since.
    local dir home out
    dir="$(new_tmpdir)"
    home="$dir/home"
    mkdir -p "$home/.config/quickshell/caelestia" "$dir/data/scripts"
    printf 'VERSION=v9.9.9\n' > "$dir/data/version.env"
    printf 'VERSION=v1.0.0\n' > "$home/.config/quickshell/caelestia/version.env"
    : > "$dir/data/scripts/03-deploy-configs.sh"

    out="$(env -u CAELESTIA_INSTALL_KIND HOME="$home" XDG_CONFIG_HOME="$home/.config" \
        CAELESTIA_BIN_DIR=/usr/bin CAELESTIA_DATA_DIR="$dir/data" "$CLI" version 2>&1)"
    assert_eq "caelestia v9.9.9" "$out" "the package's own file wins over a stale record"

    out="$(env -u CAELESTIA_INSTALL_KIND -u CAELESTIA_DATA_DIR HOME="$home" XDG_CONFIG_HOME="$home/.config" \
        CAELESTIA_BIN_DIR="$home/.local/bin" CAELESTIA_DIR="$dir/checkout" "$CLI" version 2>&1)"
    assert_eq "caelestia v1.0.0" "$out" "and a checkout reports what was installed"
}

test_the_version_file_is_named_not_guessed_at() {
    # `caelestia version` used to count two and three directory levels up from wherever
    # the command was, which is a guess at the checkout's shape.
    local cli
    cli="$(cat "$CLI")"
    assert_contains "$cli" 'DATA_DIR="${CAELESTIA_DATA_DIR:-/usr/share/caelestia}"' "a package's data directory should be named"
    assert_contains "$cli" 'VERSION_FILE="$DATA_DIR/version.env"' "and its version file read from there"
    assert_not_contains "$cli" '$BIN_DIR/../../.github/version.env' "and the command should not walk up from itself"
    assert_not_contains "$cli" '$BIN_DIR/../../../.github/version.env' "at two depths either"
}

run_tests
