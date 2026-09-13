pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    // Three settings changed shape in this release rather than value, and none of them
    // can be fixed by a different default: a key the user has written wins over the
    // default, and an array they have written replaces the default whole. So the
    // retired keys are read here, their meaning is carried into whatever succeeded
    // them, and they are then reset so the file stops carrying something nothing reads.
    // Every step returns early once it has run, which makes calling this on every
    // start the whole of the bookkeeping.

    // The status area used to be one switch per icon under `bar.status`, and the order
    // the icons were drawn in lived in a file of the bar's own. Both are the ordered
    // `bar.statusIcons` list now, so each retired switch is named here beside the entry
    // it decided, and the file is read once as the order to start the list from.
    readonly property var retiredStatusKeys: [
        { id: "lockStatus", key: "showLockStatus" },
        { id: "microphone", key: "showMicrophone" },
        { id: "kbLayout", key: "showKbLayout" },
        { id: "network", key: "showNetwork" },
        { id: "ethernet", key: "showNetwork" },
        { id: "bluetooth", key: "showBluetooth" },
        { id: "audio", key: "showAudio" },
        { id: "battery", key: "showBattery" },
        { id: "peripheralBattery", key: "showPeripheralBattery" },
        { id: "nightlight", key: "showNightLight" },
        { id: "notifications", key: "showNotifications" }
    ]
    // The two entries the list spells differently to the file. `showNetwork` decides two
    // of them at once because the network glyph and the Ethernet glyph were two halves
    // of the same switch; `showWifi` is not retired, it still gates the Wi-Fi glyph
    // riding on the network entry.
    readonly property var retiredIconNames: ({
            lockstatus: "lockStatus",
            kblayout: "kbLayout"
        })
    readonly property string orderFilePath: `${Paths.config}/status_icons_order.txt`

    // The order the file asked for, as the list spells the ids, without anything the
    // list has no entry for.
    function retiredOrder(order: string): var {
        const ids = [];
        for (const name of order.split(",")) {
            const id = root.retiredIconNames[name] ?? name;
            if (id && root.retiredStatusKeys.some(entry => entry.id === id) && !ids.includes(id))
                ids.push(id);
        }
        return ids;
    }

    // The status icons, once, from the switches and the order the bar used to keep.
    //
    // The file is removed a start later, after the list it fed is in the config: a file
    // removed in the same breath as the write would be the only copy of that order if
    // the write did not land, and removing it here is what "the migration succeeded"
    // means in practice.
    function migrateStatusIcons(order: string): void {
        const status = GlobalConfig.bar.status;
        const icons = GlobalConfig.bar.statusIcons;

        // The list is the user's own already, so what the file says has been
        // superseded by it and the file has no reader left either way.
        if (icons.isOverride("values")) {
            if (order)
                Quickshell.execDetached(["rm", "-f", root.orderFilePath]);
            return;
        }

        // Neither half of the old shape is in this config.
        if (!order && !root.retiredStatusKeys.some(entry => status.isOverride(entry.key)))
            return;

        const enabled = {};
        for (const entry of root.retiredStatusKeys)
            enabled[entry.id] = status[entry.key];

        // The entries the list ships with, in the order the file asked for, with the
        // rest of them behind: what is not in the file was not dragged anywhere.
        const shipped = icons.values.map(entry => entry.id);
        const wanted = root.retiredOrder(order).filter(id => shipped.includes(id));
        for (const id of shipped)
            if (!wanted.includes(id))
                wanted.push(id);

        for (let i = 0; i < wanted.length; i++) {
            const from = icons.values.findIndex(entry => entry.id === wanted[i]);
            if (from >= 0 && from !== i)
                icons.move(from, i);
            icons.at(i).enabled = enabled[wanted[i]] ?? false;
        }

        for (const entry of root.retiredStatusKeys)
            status.resetOption(entry.key);
    }

    // The workspace indicator used to take a boolean: `useIcon`, true for the material
    // shapes and false for the workspace number. It takes upstream's `displayType` enum
    // now, and the boolean is retired - without translating it, a config asking for
    // numbers would come back to shapes, which is what the enum defaults to once the
    // key it was written under is gone.
    function migrateWorkspaceDisplay(): void {
        const workspaces = GlobalConfig.bar.workspaces;
        if (!workspaces.isOverride("useIcon"))
            return;

        workspaces.displayType = workspaces.useIcon ? BarWorkspaceDisplay.Shapes : BarWorkspaceDisplay.Text;
        workspaces.resetOption("useIcon");
    }

    // Game Mode joined the quick toggles that ship by default in this release. The
    // array is a plain list rather than a node, so a user's own copy replaces the
    // default whole and would never gain the entry; it goes in beside Settings, where
    // the default puts it, and a user who has switched it off keeps it off.
    function migrateQuickToggles(): void {
        const utilities = GlobalConfig.utilities;
        if (!utilities.isOverride("quickToggles"))
            return;

        const toggles = utilities.quickToggles || [];
        if (toggles.some(toggle => toggle.id === "gameMode"))
            return;

        const next = toggles.map(toggle => ({ id: toggle.id, enabled: toggle.enabled !== false }));
        const settings = next.findIndex(toggle => toggle.id === "settings");
        next.splice(settings < 0 ? next.length : settings + 1, 0, { id: "gameMode", enabled: true });
        utilities.quickToggles = next;
    }

    Component.onCompleted: {
        root.migrateWorkspaceDisplay();
        root.migrateQuickToggles();
        orderReader.running = true;
    }

    Process {
        id: orderReader

        // `cat` rather than a declarative read so that the answer arrives either way:
        // what the status icons need to know is not only what the file says but that it
        // is not there at all.
        command: ["cat", root.orderFilePath]

        stdout: StdioCollector {
            id: orderOutput
        }

        onExited: root.migrateStatusIcons(orderOutput.text.trim())
    }
}
