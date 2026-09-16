#!/usr/bin/env bash

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/04a-window-rules.sh"
BASH_BIN="$(command -v bash || printf '/bin/bash')"

RULES_FILE="kwinrulesrc"
RULE_GROUPS=(caelestia-opacity caelestia-dialogs caelestia-pip)

SANDBOX=""
STUB_DIR=""
BARE_DIR=""
CALLS=""
FAKE=""
OUTPUT=""
STATUS=0

# The two config tools share one plain ini file: kwriteconfig6 rewrites it and
# kreadconfig6 answers from it, so the script's "is this value already in place"
# comparison is exercised for real instead of being answered from a fixture.
write_fake_config_tools() {
    cat > "$FAKE" <<'PY'
"""Minimal kwinrulesrc reader and writer, standing in for the two config tools."""

import sys
from pathlib import Path


def arguments(argv):
    values = {"file": "kwinrulesrc", "group": "", "key": ""}
    positional = []
    index = 0
    while index < len(argv):
        argument = argv[index]
        if argument in ("--file", "--group", "--key") and index + 1 < len(argv):
            values[argument[2:]] = argv[index + 1]
            index += 2
        else:
            positional.append(argument)
            index += 1
    return values, positional


def read(path):
    sections = {}
    current = None
    if not path.is_file():
        return sections
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
        elif current is not None and "=" in line:
            key, _, value = line.partition("=")
            sections[current][key.strip()] = value.strip()
    return sections


def write(path, sections):
    lines = []
    for name, entries in sections.items():
        lines.append("[%s]" % name)
        for key, value in entries.items():
            lines.append("%s=%s" % (key, value))
        lines.append("")
    path.write_text("\n".join(lines))


def main():
    mode = sys.argv[1]
    values, positional = arguments(sys.argv[2:])
    path = Path(values["file"])
    sections = read(path)

    if mode == "get":
        value = sections.get(values["group"], {}).get(values["key"])
        if value is None:
            return 1
        print(value)
        return 0

    sections.setdefault(values["group"], {})[values["key"]] = positional[0]
    write(path, sections)
    return 0


sys.exit(main())
PY
}

setup_sandbox() {
    SANDBOX="$(new_tmpdir)"
    STUB_DIR="$SANDBOX/bin"
    BARE_DIR="$SANDBOX/bare"
    CALLS="$SANDBOX/calls.log"
    FAKE="$SANDBOX/kwinrules.py"
    mkdir -p "$STUB_DIR" "$BARE_DIR"
    : > "$CALLS"

    write_fake_config_tools

    stub_bin "$STUB_DIR" kreadconfig6 'exec python3 "$KW_RULES" get "$@"'
    stub_bin "$STUB_DIR" kwriteconfig6 "printf '%s %s\n' 'kwriteconfig6' \"\$*\" >> \"\$KW_CALLS\"
exec python3 \"\$KW_RULES\" set \"\$@\""
    recording_stub "$STUB_DIR" qdbus6 "$CALLS"

    # A PATH holding only what the script itself needs, so that kwriteconfig6 is
    # genuinely missing rather than shadowed.
    ln -s "$(command -v dirname)" "$BARE_DIR/dirname"
    recording_stub "$BARE_DIR" qdbus6 "$CALLS"
}

run_window_rules() {
    : > "$CALLS"
    OUTPUT="$(cd "$SANDBOX" && env PATH="$STUB_DIR:$PATH" KW_CALLS="$CALLS" KW_RULES="$FAKE" "$@" bash "$SCRIPT" 2>&1)"
    STATUS=$?
}

run_window_rules_without_kwriteconfig6() {
    : > "$CALLS"
    OUTPUT="$(cd "$SANDBOX" && env PATH="$BARE_DIR" KW_CALLS="$CALLS" KW_RULES="$FAKE" "$BASH_BIN" "$SCRIPT" 2>&1)"
    STATUS=$?
}

# The frozen interface: group, key, value, in the order the script writes them.
expected_calls() {
    local opacity="$1"
    printf '%s\n' \
        "--file $RULES_FILE --group caelestia-opacity --key Description Caelestia: window opacity" \
        "--file $RULES_FILE --group caelestia-opacity --key types 33" \
        "--file $RULES_FILE --group caelestia-opacity --key opacityinactive $opacity" \
        "--file $RULES_FILE --group caelestia-opacity --key opacityinactiverule 2" \
        "--file $RULES_FILE --group caelestia-dialogs --key Description Caelestia: center dialogs" \
        "--file $RULES_FILE --group caelestia-dialogs --key types 32" \
        "--file $RULES_FILE --group caelestia-dialogs --key placement 5" \
        "--file $RULES_FILE --group caelestia-dialogs --key placementrule 2" \
        "--file $RULES_FILE --group caelestia-pip --key Description Caelestia: pin picture-in-picture" \
        "--file $RULES_FILE --group caelestia-pip --key title Picture(-| )in(-| )[Pp]icture" \
        "--file $RULES_FILE --group caelestia-pip --key titlematch 3" \
        "--file $RULES_FILE --group caelestia-pip --key above true" \
        "--file $RULES_FILE --group caelestia-pip --key aboverule 2"
}

test_a_fresh_run_writes_every_key_of_the_three_groups() {
    setup_sandbox
    run_window_rules

    assert_status 0 "$STATUS" "a fresh run should succeed"
    assert_eq "$(expected_calls 95)" "$(calls_to "$CALLS" kwriteconfig6)" \
        "every key of the frozen table should be written once, in order"
}

test_the_written_file_carries_the_groups_and_their_values() {
    setup_sandbox
    run_window_rules

    local file="$SANDBOX/$RULES_FILE"
    assert_file_exists "$file"
    assert_eq "3" "$(grep -c '^\[caelestia-' "$file")" "the file should hold exactly the three named groups"

    local content
    content="$(cat "$file")"
    local pair
    for pair in \
        "opacityinactive=95" \
        "opacityinactiverule=2" \
        "types=33" \
        "types=32" \
        "placement=5" \
        "placementrule=2" \
        "title=Picture(-| )in(-| )[Pp]icture" \
        "titlematch=3" \
        "above=true" \
        "aboverule=2"; do
        assert_contains "$content" "$pair" "the file should carry $pair"
    done
}

test_the_reload_is_called_once_and_last() {
    setup_sandbox
    run_window_rules

    assert_eq "org.kde.KWin /KWin reconfigure" "$(calls_to "$CALLS" qdbus6)" \
        "the reload should happen exactly once, with the frozen arguments"
    assert_eq "qdbus6 org.kde.KWin /KWin reconfigure" "$(tail -n 1 "$CALLS")" \
        "the reload should come after every group has been written"
}

test_only_the_own_groups_are_written() {
    setup_sandbox
    run_window_rules

    local call group
    while IFS= read -r call; do
        group="$(printf '%s\n' "$call" | awk '{ for (i = 1; i < NF; i++) if ($i == "--group") print $(i + 1) }')"
        case " ${RULE_GROUPS[*]} " in
            *" $group "*) ;;
            *) fail "kwriteconfig6 was called outside the three caelestia-* groups: $call" ;;
        esac
    done < <(calls_to "$CALLS" kwriteconfig6)

    local logged
    logged="$(cat "$CALLS")"
    assert_not_contains "$logged" "--group General" "the General group is not ours to write"
    assert_not_contains "$logged" "--key count" "count is deprecated and KWin deletes it"
    assert_not_contains "$logged" "--key rules" "a stale rules list makes KWin purge groups it does not know"
    assert_not_contains "$logged" "--key Order" "Order belongs to KWin and reordering the user's rules is not ours to do"

    assert_not_contains "$(cat "$SANDBOX/$RULES_FILE")" "[General]" \
        "the file under test should have no General section at all"
}

test_a_second_run_finds_nothing_to_do() {
    setup_sandbox
    run_window_rules
    assert_status 0 "$STATUS" "the first run should succeed"

    run_window_rules
    assert_status 0 "$STATUS" "the second run should succeed"
    assert_eq "" "$(calls_to "$CALLS" kwriteconfig6)" \
        "a config that already holds every value should need no writes"
    assert_contains "$OUTPUT" "already in place" "the second run should report the rules as already in place"
    assert_not_contains "$OUTPUT" "Window rules applied." "the second run should not claim to have applied anything"
}

test_the_step_can_be_switched_off() {
    setup_sandbox
    run_window_rules APPLY_WINDOW_RULES=false

    assert_status 0 "$STATUS" "switching the step off should not fail the install"
    assert_contains "$OUTPUT" "Skipping window rules" "the skip should be reported"
    assert_eq "" "$(cat "$CALLS")" "nothing should be written or reloaded"
    assert_file_missing "$SANDBOX/$RULES_FILE"
}

test_a_missing_kwriteconfig6_warns_instead_of_failing() {
    setup_sandbox
    run_window_rules_without_kwriteconfig6

    assert_status 0 "$STATUS" "a missing kwriteconfig6 should not fail the install"
    assert_contains "$OUTPUT" "kwriteconfig6 not found" "the warning should name the missing tool"
    assert_eq "" "$(cat "$CALLS")" "nothing should be written or reloaded"
}

test_the_inactive_opacity_comes_from_the_environment() {
    setup_sandbox
    run_window_rules WINDOW_OPACITY=80

    assert_status 0 "$STATUS" "a custom opacity should not fail"
    assert_eq "$(expected_calls 80)" "$(calls_to "$CALLS" kwriteconfig6)" \
        "only the opacity value should differ from a default run"
    assert_contains "$(cat "$SANDBOX/$RULES_FILE")" "opacityinactive=80" "the file should carry it too"
}

run_tests
