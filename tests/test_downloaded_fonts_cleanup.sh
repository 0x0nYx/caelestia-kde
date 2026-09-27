#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SHELL="$REPO_ROOT/scripts/08-build-shell.sh"

# The cleanup only ever touches the user's own asset directory, so the test drives the
# real function against a throwaway HOME rather than stubbing the filesystem.
extract_function() {
    awk -v name="$1" '
        $0 ~ "^" name "\\(\\) \\{" { capture = 1 }
        capture { print }
        capture && $0 == "}" { exit }
    ' "$BUILD_SHELL"
}

CLEANUP_SOURCE="$(extract_function cleanup_downloaded_fonts)"

if [[ -z "$CLEANUP_SOURCE" ]]; then
    fail "could not find cleanup_downloaded_fonts in scripts/08-build-shell.sh"
    run_tests
    exit 1
fi

# The step scripts log through lib/log.sh, which this harness does not source.
LOG_STUBS='
ok() { :; }
info() { :; }
warn() { :; }
skip() { :; }
'

run_cleanup() {
    local home="$1"
    HOME="$home" XDG_DATA_HOME= bash -c "${LOG_STUBS}${CLEANUP_SOURCE}
cleanup_downloaded_fonts" 2>&1
}

assets_dir() {
    printf '%s\n' "$1/.local/share/caelestia/assets"
}

# The directory 12-fetch-assets.sh used to leave behind, with one file of the user's own
# next to it and the emoji database the same parent directory holds.
seed_downloaded_fonts() {
    local home="$1" fonts
    fonts="$(assets_dir "$home")/fonts"
    mkdir -p "$fonts/SF-Pro" "$fonts/SF-Mono" "$fonts/google-sans-flex"
    printf 'font\n' > "$fonts/SF-Pro/SF-Pro.ttf"
    printf 'font\n' > "$fonts/SF-Mono/SF-Mono-Regular.otf"
    printf 'font\n' > "$fonts/google-sans-flex/GoogleSansFlex-Subset.ttf"
    printf '# Fonts\n\nThe shell loads every .ttf/.otf found here at startup.\n' > "$fonts/README.md"
    printf 'mine\n' > "$fonts/MyFont.ttf"
    printf 'emoji\n' > "$(assets_dir "$home")/emojis.txt"
}

test_the_fonts_an_older_install_downloaded_go() {
    local home fonts
    home="$(new_tmpdir)"
    seed_downloaded_fonts "$home"
    fonts="$(assets_dir "$home")/fonts"

    run_cleanup "$home" >/dev/null

    assert_file_missing "$fonts/SF-Pro"
    assert_file_missing "$fonts/SF-Mono"
    assert_file_missing "$fonts/google-sans-flex"
    assert_file_missing "$fonts/README.md"
}

test_the_users_own_font_and_the_emoji_database_stay() {
    local home fonts
    home="$(new_tmpdir)"
    seed_downloaded_fonts "$home"
    fonts="$(assets_dir "$home")/fonts"

    run_cleanup "$home" >/dev/null

    assert_file_exists "$fonts/MyFont.ttf"
    assert_file_exists "$(assets_dir "$home")/emojis.txt"
}

test_only_the_shipped_readme_is_removed() {
    local home fonts
    home="$(new_tmpdir)"
    fonts="$(assets_dir "$home")/fonts"
    mkdir -p "$fonts"
    printf 'mine\n' > "$fonts/MyFont.ttf"
    printf '# My own font notes\n' > "$fonts/README.md"

    run_cleanup "$home" >/dev/null

    assert_file_exists "$fonts"
    assert_file_exists "$fonts/MyFont.ttf"
    assert_file_exists "$fonts/README.md"
}

test_a_machine_that_never_downloaded_anything_is_a_no_op() {
    local home status
    home="$(new_tmpdir)"

    run_cleanup "$home" >/dev/null
    status=$?

    assert_status 0 "$status" "the cleanup should not fail when there is nothing to remove"
    assert_file_missing "$(assets_dir "$home")/fonts"
}

test_the_fonts_directory_goes_once_it_is_empty() {
    local home fonts
    home="$(new_tmpdir)"
    fonts="$(assets_dir "$home")/fonts"
    mkdir -p "$fonts/SF-Pro"
    printf 'font\n' > "$fonts/SF-Pro/SF-Pro.ttf"
    printf 'emoji\n' > "$(assets_dir "$home")/emojis.txt"

    run_cleanup "$home" >/dev/null

    assert_file_missing "$fonts"
    assert_file_exists "$(assets_dir "$home")/emojis.txt"
}

run_tests
