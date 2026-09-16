import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Keep configuration migration and notification registration ahead of
        // other applications, then defer the rest until the shell has started.
        ConfigMigrations;
        Notifs;
    }

    Timer {
        id: deferredServices

        interval: 250
        repeat: false
        running: true

        onTriggered: {
            IdleInhibitor;
            GameMode;
            Players;
            Brightness;
            Weather.reload();
            WorkspaceTrackerGuard;
            PowerDevil;

            if (GlobalConfig.utilities.vpn.enabled)
                VPN;
        }
    }
}
