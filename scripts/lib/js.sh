#!/usr/bin/env bash
# js.sh - Put a value inside JavaScript source safely.
#
# Plasma's scripting interface takes a script as text and evaluates it, so a value
# that came from the user - a wallpaper path, most often - ends up interpolated into
# source. A quote in that value would end the string literal early and whatever
# followed it would be read as code; a newline would break the statement; and a
# backslash would silently change the characters after it.
#
# js_string writes a literal that cannot do any of that: everything outside
# [A-Za-z0-9/._:-] becomes a \uXXXX escape. The result is made of characters that
# mean the same thing to JavaScript, to the shell and to a single-quoted literal, so
# no layer between here and Plasma rewrites what it says - and it is pure bash, since
# needing an installed interpreter on the machine of a user whose wallpaper has an
# apostrophe in its name is exactly the kind of dependency that turns into a bug.
#
#   js_string "file://$HOME/a'b.jpg"   # -> file:///home/u/a\u0027b.jpg
#
# Guard against double-sourcing, written as an if so a false test never trips
# `set -e` in the sourcing script.
if [[ -z "${CAELESTIA_JS_SOURCED:-}" ]]; then
CAELESTIA_JS_SOURCED=1

# js_string <value>
js_string() {
    local text="$1" out="" i ch code

    for ((i = 0; i < ${#text}; i++)); do
        ch="${text:i:1}"
        case "$ch" in
            [A-Za-z0-9/._:-]) out+="$ch" ;;
            *)
                printf -v code '%d' "'$ch"
                if ((code > 0xFFFF)); then
                    # Outside the basic plane, which one \u escape cannot carry:
                    # JavaScript spells those as a surrogate pair.
                    local value=$((code - 0x10000))
                    printf -v out '%s\\u%04x\\u%04x' "$out" "$((0xD800 + (value >> 10)))" "$((0xDC00 + (value & 0x3FF)))"
                else
                    printf -v out '%s\\u%04x' "$out" "$code"
                fi
                ;;
        esac
    done

    printf '%s' "$out"
}
fi
