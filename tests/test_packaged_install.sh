#!/usr/bin/env bash
# test_packaged_install.sh - Tests for `caelestia install` on a packaged machine.
#
# The split under test is parity-6: a package owns /usr and /etc, and the command
# owns the user's half. So `install` has to do two different things depending on
# which kind of install it finds itself in, and the packaged half has to be the
# same step scripts the checkout's installer runs - told which install they are
# part of, so the sections that write package-owned files stay out.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$REPO_ROOT/src/bin/caelestia"

# The steps a packaged install runs, in order. Kept here as the list the test
# expects, so a change to the dispatcher's list has to be deliberate.
EXPECTED_STEPS=(03-deploy-configs.sh 03a-wallpapers.sh 04-deploy-kde.sh 05-sddm-theme.sh 06-services.sh 08-build-shell.sh 09-system-tweaks.sh 10-autostart.sh)

DIR=""
CALLS=""
DATA=""

# stub_steps <failing-step|"">
#
# One stub per step, recording the environment it was given. The stubs are run
# with `bash <path>`, so they need no shebang and no execute bit.
stub_steps() {
    local failing="$1" step
    DIR="$(new_tmpdir)"
    DATA="$DIR/data"
    CALLS="$DIR/calls.log"
    mkdir -p "$DATA/scripts"
    : > "$CALLS"

    for step in "${EXPECTED_STEPS[@]}"; do
        {
            printf 'printf "%%s|%%s|%%s\\n" "%s" "$BUNDLE_DIR" "$CAELESTIA_INSTALL_KIND" >> "%s"\n' "$step" "$CALLS"
            [[ "$step" == "$failing" ]] && printf 'exit 3\n'
            printf 'exit 0\n'
        } > "$DATA/scripts/$step"
    done
}

# run_install <extra-env-assignments...>
run_install() {
    local env_prefix=()
    while [[ $# -gt 0 ]]; do
        env_prefix+=("$1")
        shift
    done
    env "${env_prefix[@]}" "$CLI" install > "$DIR/out.txt" 2>&1
    RUN_STATUS=$?
}

RUN_STATUS=0
RUN_OUTPUT=""

test_a_checkout_install_is_still_the_installer() {
    # With a checkout named, install hands over to it, exactly as before.
    DIR="$(new_tmpdir)"
    mkdir -p "$DIR/checkout"
    printf '#!/bin/sh\necho "checkout installer ran"\n' > "$DIR/checkout/install.sh"

    CAELESTIA_DIR="$DIR/checkout" "$CLI" install > "$DIR/out.txt" 2>&1
    assert_status 0 "$?" "a checkout install should succeed"
    assert_contains "$(cat "$DIR/out.txt")" "checkout installer ran" "install should run the checkout's own installer"
}

test_a_checkout_that_is_not_named_is_refused_with_its_installer() {
    # What `packaged_data_dir` finds instead of a package when run from a checkout:
    # the repo's own scripts. Installing half of a checkout from here would be a
    # half install, so it must send the user to install.sh.
    stub_steps ""
    CAELESTIA_DATA_DIR="$REPO_ROOT" "$CLI" install > "$DIR/out.txt" 2>&1
    local status=$?

    assert_status 1 "$status" "a checkout with no CAELESTIA_DIR should be refused"
    assert_contains "$(cat "$DIR/out.txt")" "is a checkout, not a package install" "the refusal should say which install it found"
    assert_contains "$(cat "$DIR/out.txt")" "$REPO_ROOT/install.sh" "the refusal should name the installer to run instead"
    assert_eq "" "$(cat "$CALLS")" "no step should have run"
}

test_the_packaged_half_runs_the_user_steps_in_order() {
    stub_steps ""
    CAELESTIA_DATA_DIR="$DATA" CAELESTIA_INSTALL_KIND=package "$CLI" install > "$DIR/out.txt" 2>&1
    local status=$?
    assert_status 0 "$status" "the packaged half should succeed"

    local expected="" step
    for step in "${EXPECTED_STEPS[@]}"; do
        [[ -n "$expected" ]] && expected+=$'\n'
        expected+="$step|$DATA|package"
    done
    assert_eq "$expected" "$(cat "$CALLS")" "every user-half step should run once, in order, told which install it is part of"
}

test_the_machine_steps_stay_out_of_a_packaged_install() {
    stub_steps ""
    CAELESTIA_DATA_DIR="$DATA" CAELESTIA_INSTALL_KIND=package "$CLI" install > "$DIR/out.txt" 2>&1

    # The steps that install packages, fetch the submodules and build the shell are
    # the package's own work; running them again would write into /usr and /etc
    # behind pacman.
    local calls
    calls="$(cat "$CALLS")"
    local absent
    for absent in 00-refresh-mirrors.sh 00a-system-update.sh 01-ensure-prereqs.sh 02-all-packages.sh 02a-submodules.sh 07-kde-apps.sh 11-optional-apps.sh; do
        assert_not_contains "$calls" "$absent" "$absent belongs to the package, not to the user's half"
    done
}

test_the_greeter_step_selects_without_installing_the_theme() {
    # 05 runs on a packaged install because choosing a login screen is the user's
    # half, but everything it would write under /usr and /etc is the package's.
    local script
    script="$(cat "$REPO_ROOT/scripts/05-sddm-theme.sh")"

    assert_contains "$script" 'skip "The theme files belong to the package."' "the theme copy should be skipped"
    assert_contains "$script" 'skip "The theme selection belongs to the package."' "the selection under /etc should be skipped"
    assert_contains "$script" "skip \"The display manager's dependencies belong to the package.\"" "the distro dependencies should be skipped"
    assert_contains "$script" 'register_greeter_sync "SDDM theme installed."' "while the posthook is still registered for both kinds"

    # And the package ships what the step no longer writes, or a packaged install
    # would have no theme to select at all.
    local pkgbuild
    pkgbuild="$(cat "$REPO_ROOT/packaging/aur/caelestia-shell-kde/PKGBUILD")"
    assert_contains "$pkgbuild" 'usr/share/sddm/themes/caelestia' "the package should install the theme"
    assert_contains "$pkgbuild" 'scripts/sync.sh' "and the helper the posthook runs"
    assert_contains "$pkgbuild" 'etc/sddm.conf.d/zz-caelestia.conf' "and the drop-in that selects it"
    assert_contains "$pkgbuild" 'usr/lib/udev/rules.d/80-uinput.rules' "and the udev rule the system block writes for a checkout"
}

test_a_failing_step_stops_the_run() {
    stub_steps "04-deploy-kde.sh"
    CAELESTIA_DATA_DIR="$DATA" CAELESTIA_INSTALL_KIND=package "$CLI" install > "$DIR/out.txt" 2>&1
    local status=$?

    assert_status 1 "$status" "a failing step should fail the run"
    assert_contains "$(cat "$DIR/out.txt")" "04-deploy-kde.sh failed" "the failure should name the step"
    assert_not_contains "$(cat "$CALLS")" "06-services.sh" "nothing after the failing step should run"
}

test_missing_scripts_say_where_they_come_from() {
    # A command installed somewhere with no data directory beside it: /usr/bin with
    # no package, or a copy in a test's scratch space.
    DIR="$(new_tmpdir)"
    mkdir -p "$DIR/bin"
    cp "$CLI" "$DIR/bin/caelestia"

    env -u CAELESTIA_DATA_DIR -u CAELESTIA_LIB_DIR HOME="$DIR/home" "$DIR/bin/caelestia" install > "$DIR/out.txt" 2>&1
    local status=$?

    assert_status 1 "$status" "no scripts should be an error"
    assert_contains "$(cat "$DIR/out.txt")" "no installer scripts found" "the error should say what is missing"
    assert_contains "$(cat "$DIR/out.txt")" "/usr/share/caelestia" "the error should say where a package keeps them"
}

test_install_help_describes_the_user_half() {
    local out
    out="$("$CLI" install --help 2>&1)"
    assert_contains "$out" "this user's half" "install should describe what it now does"
    assert_contains "$out" "idempotently" "and that it can be run again"
}

run_tests
