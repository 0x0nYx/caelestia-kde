pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    id: root

    /// Seconds of inactivity before Caelestia suspends the session, or 0 when it
    /// has no suspend action enabled. The suspend timeout has one owner, so this
    /// is the question callers ask instead of scanning the list themselves.
    readonly property int suspendSeconds: {
        const entries = GlobalConfig.general.idle.timeouts ?? [];

        for (const entry of entries) {
            if (!root.isSuspendIdleAction(entry.idleAction) || !(entry.enabled ?? false))
                continue;

            const seconds = Number(entry.timeout);
            if (isFinite(seconds) && seconds > 0)
                return Math.round(seconds);
        }

        return 0;
    }

    function isSuspendIdleAction(action: var): bool {
        if (!action)
            return false;

        if (typeof action === "string") {
            const normalized = action.trim().toLowerCase();
            return normalized === "suspendthenhibernate" || normalized === "suspend" || normalized === "suspend-then-hibernate" || normalized === "systemctl suspend" || normalized === "systemctl suspend-then-hibernate";
        }

        const isArrayLike = action instanceof Array || (typeof action === "object" && action.length !== undefined);
        if (isArrayLike) {
            for (const a of action) {
                if (root.isSuspendIdleAction(a))
                    return true;
            }
        }

        return false;
    }
}