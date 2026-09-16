#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

RULES_FILE="kwinrulesrc"
WINDOW_OPACITY="${WINDOW_OPACITY:-95}"
RULE_WRITES=0

# Read every key before writing it, so a second run reports the rules that were
# already in place instead of claiming a fresh write.
set_rule_key() {
    local group="$1" key="$2" value="$3" current
    current="$(kreadconfig6 --file "$RULES_FILE" --group "$group" --key "$key" 2>/dev/null || true)"
    if [[ "$current" == "$value" ]]; then
        return 0
    fi
    kwriteconfig6 --file "$RULES_FILE" --group "$group" --key "$key" "$value" 2>/dev/null || true
    RULE_WRITES=$((RULE_WRITES + 1))
}

# Only the keys of our own named groups are written. kwinrulesrc is the user's
# file: it is never truncated, [General] is never touched, and unknown groups stay.
apply_rule_group() {
    local group="$1" label="$2" before="$RULE_WRITES"
    shift 2
    while [[ $# -ge 2 ]]; do
        set_rule_key "$group" "$1" "$2"
        shift 2
    done
    if (( RULE_WRITES > before )); then
        ok "Applied $label."
    else
        skip "$label already in place."
    fi
}

echo
echo ""
info "Applying KWin window rules"
echo ""

if [[ "${APPLY_WINDOW_RULES:-true}" == "true" ]]; then
    if ! command -v kwriteconfig6 >/dev/null 2>&1; then
        warn "kwriteconfig6 not found - skipping window rules."
        exit 0
    fi

    # KWin has no floating action and no keepabove key: a rule cannot make a window
    # float, and the keep-above action below is spelled above.

    # types=33 is Normal|Dialog, so panels, tooltips and the OSD keep full opacity.
    apply_rule_group "caelestia-opacity" "window opacity" \
        Description "Caelestia: window opacity" \
        types 33 \
        opacityinactive "$WINDOW_OPACITY" \
        opacityinactiverule 2

    # The rule placement is a bare integer, 5 being PlacementCentered; the global
    # [Windows] Placement key in kwinrc is a string, this one is not.
    apply_rule_group "caelestia-dialogs" "dialog centering" \
        Description "Caelestia: center dialogs" \
        types 32 \
        placement 5 \
        placementrule 2

    # No types key here: picture-in-picture windows are Normal or Dialog depending
    # on the app, and the title regex is specific enough on its own.
    apply_rule_group "caelestia-pip" "picture-in-picture pin" \
        Description "Caelestia: pin picture-in-picture" \
        title "Picture(-| )in(-| )[Pp]icture" \
        titlematch 3 \
        above true \
        aboverule 2

    # One reload, after every group is written: KWin drops groups it has not read
    # yet when it saves the file, so reloading between writes loses rules.
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    else
        warn "qdbus6 not found - KWin picks the rules up on its next restart."
    fi

    if (( RULE_WRITES > 0 )); then
        ok "Window rules applied."
    else
        skip "Window rules already in place."
    fi
else
    skip "Skipping window rules"
fi
