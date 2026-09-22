pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property bool idleSuspendEnabledState: false
    property int idleSuspendMinutesState: 10

    // The suspend entry of the idle timeouts, or null when the user has not added one.
    // The list is a config node now, so entries are read and written in place instead of
    // being copied out and written back as a whole.
    function suspendTimeout(): var {
        return GlobalConfig.general.idle.timeouts.values.find(t => IdleActions.isSuspendIdleAction(t.idleAction)) ?? null;
    }

    // The props for a suspend entry, used when the user turns the suspend timeout on
    // without one in the config.
    function suspendProps(timeoutSeconds: int): var {
        return {
            "timeout": timeoutSeconds,
            "idleAction": ["suspendThenHibernate"],
            "enabled": true,
            "respectInhibitors": true
        };
    }

    function refreshIdleSuspendState(): void {
        const seconds = IdleActions.suspendSeconds;
        root.idleSuspendEnabledState = seconds > 0;
        root.idleSuspendMinutesState = seconds > 0 ? Math.round(seconds / 60) : 10;
    }

    function setSuspendTimeoutMinutes(minutes: int): void {
        const sanitizedMinutes = Math.max(1, Math.min(180, Math.round(minutes)));
        const timeoutSeconds = sanitizedMinutes * 60;
        const suspend = root.suspendTimeout();

        if (suspend)
            suspend.timeout = timeoutSeconds;
        else
            GlobalConfig.general.idle.timeouts.insert(root.suspendProps(timeoutSeconds));

        root.refreshIdleSuspendState();
    }

    function setSuspendTimeoutEnabled(enabled: bool): void {
        const suspend = root.suspendTimeout();

        if (suspend)
            suspend.enabled = enabled;
        else if (enabled)
            GlobalConfig.general.idle.timeouts.insert(root.suspendProps(root.idleSuspendMinutesState * 60));

        root.refreshIdleSuspendState();
    }

    Component.onCompleted: root.refreshIdleSuspendState()

    title: qsTr("Power")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Idle & sleep")
        }

        ToggleRow {
            first: true
            text: qsTr("Idle suspend")
            subtext: qsTr("Suspend the system after inactivity")
            checked: root.idleSuspendEnabledState
            onToggled: root.setSuspendTimeoutEnabled(checked)
        }

        StepperRow {
            enabled: root.idleSuspendEnabledState
            label: qsTr("Idle suspend timer")
            subtext: root.idleSuspendEnabledState
                     ? qsTr("Suspend after %1 minute(s) of inactivity").arg(root.idleSuspendMinutesState)
                     : qsTr("Enable idle suspend to apply a timer")
            value: root.idleSuspendMinutesState
            from: 1
            to: 180
            stepSize: 1
            onMoved: v => {
                if (root.idleSuspendEnabledState)
                    root.setSuspendTimeoutMinutes(v)
            }
        }

        ToggleRow {
            text: qsTr("Lock before sleep")
            subtext: qsTr("Lock the session before suspending")
            checked: Config.general.idle.lockBeforeSleep
            onToggled: GlobalConfig.general.idle.lockBeforeSleep = checked
        }

        ToggleRow {
            text: qsTr("Inhibit while audio")
            subtext: qsTr("Prevent idle actions while audio is playing")
            checked: Config.general.idle.inhibitWhenAudio
            onToggled: GlobalConfig.general.idle.inhibitWhenAudio = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Inhibit while charging")
            subtext: qsTr("Prevent idle actions while charging")
            checked: Config.general.idle.inhibitWhenCharging
            onToggled: GlobalConfig.general.idle.inhibitWhenCharging = checked
        }

        SectionHeader {
            text: qsTr("Battery warnings")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Critical battery level")
            subtext: qsTr("Percentage at which the critical warning fires")
            value: Config.general.battery.criticalLevel
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.general.battery.criticalLevel = v
        }
    }
}
