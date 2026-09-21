pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property SystemTrayItem modelData
    property int trayIndex: -1
    property var popouts
    property bool isHorizontal: false
    readonly property bool hasMenuEntries: menuOpener.children.values.some(entry => !entry.isSeparator)

    // The middle click is the item's secondary activation, which is what the
    // protocol defines it as and what upstream's tray does for every click that is
    // not the left one; it was not accepted before, so it did nothing.
    //
    // The right click keeps our menu, which is what a Plasma tray does, but only
    // when there is something to show: a menu that is empty or absent used to pop
    // an empty box over the bar. With nothing to show it falls back to the same
    // secondary activation, and so does a right click with no popout host to
    // render into.
    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.extraSmall
        implicitHeight: root.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        Accessible.role: Accessible.Button
        Accessible.name: root.modelData.title || root.modelData.id
        // Whichever of the two the click handler above would take: promising a menu on
        // a right click that runs the secondary action instead is the kind of guidance
        // a screen reader user has no way to check.
        Accessible.description: root.hasMenuEntries && root.popouts ? qsTr("Left-click activates, right-click opens the menu, middle-click runs the secondary action.") : qsTr("Left-click activates, middle- or right-click runs the secondary action.")

        onClicked: event => {
            if (event.button === Qt.LeftButton) {
                root.modelData.activate();
            } else if (event.button === Qt.MiddleButton || !root.hasMenuEntries || !root.popouts) {
                root.modelData.secondaryActivate();
            } else {
                root.popouts.currentName = `traymenu${root.trayIndex}`;
                root.popouts.currentCenter = root.isHorizontal
                    ? root.mapToItem(null, root.implicitWidth / 2, 0).x
                    : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                root.popouts.hasCurrent = true;
            }
        }
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.modelData.menu // qmllint disable unresolved-type
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
