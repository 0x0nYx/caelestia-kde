pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
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

    // A wheel over the stepper, or a held key, moves the value several times in a
    // row; collapsing those keeps an in-flight run from writing a value the user
    // has already moved past.
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

        onExited: code => {
            if (code === 0)
                return;

            // The setting reads as applied in Nexus either way, so a failed
            // write has to be said out loud.
            console.warn("[PowerDevil] could not line KDE's idle-suspend timers up with the Caelestia timeout");
            Toaster.toast(qsTr("KDE's suspend timer was not updated"), qsTr("Its own timer in System Settings > Power Management can still suspend before the timeout set here."), "warning", Toast.Warning);
        }
    }
}
