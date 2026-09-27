#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DIR="$REPO_ROOT/shell"

# The invariants worth pinning here are the ones a compiler or a QML engine
# cannot see: that a settings read cannot silently resolve to nothing, and that
# the pieces which must agree on the profile id still do. Everything else about
# this feature is behavior, and belongs in a harness that can run it.

test_every_hotspot_setting_reader_uses_global_config() {
    # A global property is only reachable through GlobalConfig. Reading it off
    # Config resolves to nothing, so a field would stay empty and a one-tap
    # toggle would start an access point with the wrong name: no error, no
    # warning, just the wrong network.
    local readers
    readers="$(grep -rn 'Config\.services\.hotspot' "$SHELL_DIR" --include='*.qml' \
        | grep -v 'GlobalConfig\.services\.hotspot' || true)"

    assert_eq "" "$readers" "every reader of the hotspot settings should use GlobalConfig"
}

test_the_profile_id_has_one_definition() {
    # The id names a connection NetworkManager and Plasma both key on. It is
    # declared once, in the controller, and the UI reads it from there: a second
    # literal would be free to drift from this one.
    local controller="$REPO_ROOT/shell/plugin/src/Caelestia/Services/HotspotController.cpp"

    assert_file_exists "$controller"
    assert_eq "1" "$(grep -c 'caelestia-hotspot' "$controller")" \
        "the profile id should be written once, in the controller"

    local literals
    literals="$(grep -rn 'caelestia-hotspot' "$SHELL_DIR" --include='*.qml' || true)"
    assert_eq "" "$literals" "no QML file should carry its own copy of the profile id"
}

test_the_hotspot_state_has_one_owner() {
    # Supported, enabled, the name and the in-flight flag all change together.
    # Copying them through the Nmcli adapter is what makes a switch have to guess
    # which copy is authoritative, so the adapter hands over the service instead.
    local adapter
    adapter="$(cat "$SHELL_DIR/services/Nmcli.qml")"

    assert_contains "$adapter" "readonly property HotspotController hotspot: NmQt.hotspot" \
        "Nmcli should expose the hotspot controller itself"
    assert_not_contains "$adapter" "readonly property bool hotspotSupported" \
        "Nmcli should not copy the hotspot state into its own properties"
}

test_every_switch_reads_the_backend() {
    # A switch that writes its own checked and then reads the backend has to
    # reconcile the two, and every surface that does it needs its own copy of
    # that reconciliation. Binding checked to the backend makes the tap a no-op
    # on failure instead.
    local file
    for file in \
        "$SHELL_DIR/modules/utilities/cards/Toggles.qml" \
        "$SHELL_DIR/modules/nexus/pages/network/HotspotPage.qml" \
        "$SHELL_DIR/modules/bar/popouts/Network.qml"; do
        assert_contains "$(cat "$file")" "Nmcli.hotspot.enabled" \
            "$(basename "$file") should read the hotspot state from the controller"
    done

    local leftover
    leftover="$(grep -rn 'Binding on checked' "$SHELL_DIR/modules" --include='*.qml' || true)"
    assert_eq "" "$leftover" "no switch should need a Binding to survive its own click"
}

test_one_tap_does_not_share_an_open_network() {
    # With nothing configured, starting the hotspot would share an open network
    # under the machine's hostname. The refusal lives with the one-tap path, not
    # in the adapter, and points at the page where an open network is a choice.
    local switch
    switch="$(cat "$SHELL_DIR/services/HotspotSwitch.qml")"

    assert_contains "$switch" 'hotspotSsid.length === 0 && hotspotPassword.length === 0' \
        "an unconfigured hotspot should not start"
    assert_contains "$switch" "Settings > Network > Hotspot" \
        "and the refusal should say where to set it up"

    local adapter
    adapter="$(cat "$SHELL_DIR/services/Nmcli.qml")"
    assert_not_contains "$adapter" "Toaster.toast" \
        "a passthrough adapter should not own a user-facing decision"
}

test_the_profile_id_is_read_not_restated() {
    # The help text names the profile so a user can find it in Plasma's applet.
    # It reads the id from the controller so the sentence cannot outlive a rename.
    local page
    page="$(cat "$SHELL_DIR/modules/nexus/pages/network/HotspotPage.qml")"

    assert_contains "$page" "Nmcli.hotspot.profileId" \
        "the page should read the profile id from the controller"
}

test_the_password_rule_agrees_across_the_layers() {
    # WPA cannot carry a passphrase under eight characters, so the controller
    # refuses one and the form refuses to save one. Two copies of the rule can
    # drift apart silently, which is why both sides are pinned here.
    local controller="$REPO_ROOT/shell/plugin/src/Caelestia/Services/HotspotController.cpp"
    local page="$SHELL_DIR/modules/nexus/pages/network/HotspotPage.qml"

    assert_contains "$(cat "$controller")" "if (!password.isEmpty() && password.size() < 8)" \
        "the controller should refuse a password under eight characters"
    assert_contains "$(cat "$page")" "validate: text => text.length === 0 || text.length >= 8" \
        "the form should refuse the same password"
}

run_tests
