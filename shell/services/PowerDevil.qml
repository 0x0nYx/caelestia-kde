pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// powerdevil keeps its own idle-suspend timer per power profile and the shortest
// one wins, so a 30 minute setting in Nexus still suspended at KDE's default 10
// minutes on battery, with nothing on screen to say a second timer existed.
// Whenever Caelestia's timeout changes - including when the config lands - KDE's
// profiles are lined up with it.
Singleton {
    id: root

    readonly property int suspendSeconds: IdleActions.suspendSeconds

    function mirror(): void {
        settle.restart();
    }

    Component.onCompleted: root.mirror()

    onSuspendSecondsChanged: root.mirror()

    // A stepped value changes several times in a row, and a run already in
    // flight would miss the last one.
    Timer {
        id: settle

        interval: 200

        onTriggered: {
            mirroring.running = false;
            mirroring.running = true;
        }
    }

    Process {
        id: mirroring

        command: ["bash", Quickshell.shellPath("scripts/mirror-idle-suspend.sh"), String(root.suspendSeconds)]
    }
}
