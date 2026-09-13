pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var builtinIcons: ({
            lockStatus: qsTr("Lock keys"),
            kbLayout: qsTr("Keyboard layout"),
            audio: qsTr("Speakers"),
            microphone: qsTr("Microphone"),
            network: qsTr("Network"),
            ethernet: qsTr("Ethernet"),
            bluetooth: qsTr("Bluetooth"),
            battery: qsTr("Battery"),
            peripheralBattery: qsTr("Peripheral battery"),
            nightlight: qsTr("Night light"),
            notifications: qsTr("Notifications")
        })
    readonly property var addableIcons: {
        const present = Config.bar.statusIcons.values.map(entry => entry.id);
        return Object.keys(root.builtinIcons).filter(id => !present.includes(id)).map(id => ({ id: id, label: root.builtinIcons[id] }));
    }

    title: qsTr("Status icons")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Visible icons
        SectionHeader {
            first: true
            text: qsTr("Visible icons")
        }

        // An ordered list rather than a wall of switches: what is in it is what the
        // bar draws, in the order it draws it, and entries can be added, removed
        // and dragged from here.
        ListEditor {
            function labelFor(item: var): string {
                return root.builtinIcons[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: Config.bar.statusIcons.values
            onItemMoved: (from, to) => GlobalConfig.bar.statusIcons.move(from, to)
            onItemRemoved: index => GlobalConfig.bar.statusIcons.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.bar.statusIcons.at(index).enabled = checked
        }

        // Only what the list does not have yet: an entry that is in it is already
        // there to be switched or dragged, and adding a second copy would draw the
        // icon twice and leave `move` unable to tell the two apart, as it finds an
        // entry by id. When everything is in the list the row goes away rather than
        // offering an empty picker.
        DialogSelectButton {
            id: addItemContainer

            rootParent: root.flickable
            visible: root.addableIcons.length > 0
            icon: "add"
            label: qsTr("Add entry")
            header: qsTr("Add new entry")
            acceptLabel: qsTr("Add")

            model: root.addableIcons

            onAccepted: {
                if (selectedItem)
                    GlobalConfig.bar.statusIcons.insert({ id: selectedItem, enabled: true });
            }
        }

        // Not an icon of its own: the Wi-Fi glyph rides on the network entry.
        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Wi-Fi")
            subtext: qsTr("Show the Wi-Fi icon alongside the network icon")
            checked: Config.bar.status.showWifi
            onToggled: GlobalConfig.bar.status.showWifi = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behavior")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a details popout when hovering the status icons")
            checked: Config.bar.popouts.statusIcons
            onToggled: GlobalConfig.bar.popouts.statusIcons = checked
        }
    }
}
