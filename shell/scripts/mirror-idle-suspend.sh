#!/usr/bin/env bash

# Lines KDE's own idle-suspend timers up with Caelestia's, because powerdevil
# keeps one per power profile and the shortest one wins: a 30 minute setting in
# Nexus still suspended at KDE's default 10 minutes on battery, with nothing on
# screen to say a second timer existed.
#
# Only the profiles that answer "how long may the machine idle" are touched. The
# low battery profile is left alone on purpose: it exists to get the machine to
# sleep before the battery dies, not to express an idle preference.
#
# Usage: mirror-idle-suspend.sh <seconds>. 0 means Caelestia does not own the
# suspend timeout and KDE's own timers are left as they are.

set -euo pipefail

seconds="${1:-0}"
[[ "$seconds" =~ ^[0-9]+$ ]] || exit 0
(( seconds > 0 )) || exit 0

# Without these there is nothing to read or write, and a missing tool must not be
# mistaken for a profile that needs changing.
command -v kreadconfig6 >/dev/null 2>&1 || exit 0
command -v kwriteconfig6 >/dev/null 2>&1 || exit 0

read_profile() {
    kreadconfig6 --file powermanagementprofilesrc --group "$1" --group SuspendAndShutdown \
        --key "$2" --default "$3" 2>/dev/null || printf '%s' "$3"
}

for profile in AC Battery; do
    # 1 is sleep and 2 is hibernate. Anything else means powerdevil will not
    # suspend on its own, so there is no second timer to line up.
    case "$(read_profile "$profile" AutoSuspendAction 0)" in
        1 | 2) ;;
        *) continue ;;
    esac

    if [[ "$(read_profile "$profile" AutoSuspendIdleTimeoutSec 0)" != "$seconds" ]]; then
        kwriteconfig6 --file powermanagementprofilesrc --group "$profile" --group SuspendAndShutdown \
            --key AutoSuspendIdleTimeoutSec "$seconds"
    fi
done
