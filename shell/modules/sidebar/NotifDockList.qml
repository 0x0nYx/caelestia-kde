pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

LazyListView {
    id: root

    required property Props props
    required property Flickable container
    required property DrawerVisibilities visibilities

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: contentHeight

    spacing: Tokens.spacing.small
    readyDelay: 1
    cacheBuffer: 400
    asynchronous: true

    onViewportAdjustNeeded: d => {
        if (contentYAnim.running)
            contentYAnim.complete();
        contentYAnim.to = Math.max(0, container.contentY + d);
        contentYAnim.start();
    }

    useCustomViewport: true
    viewport: Qt.rect(0, container.contentY, width, container.height)

    removeDuration: Tokens.anim.durations.normal

    model: ScriptModel {
        values: {
            const map = new Map();
            for (const n of Notifs.list.filter(n => !n.closed))
                map.set(n.appName, null);
            for (const n of Notifs.list)
                map.set(n.appName, null);
            return [...map.keys()];
        }
    }

    delegate: Component {
        NotifSwipeDelegate {
            id: notif

            required property int index
            required property string modelData

            readonly property bool closed: notifInner.notifCount === 0

            function closeAll(): void {
                clearTimer.start();
            }

            LazyListView.trackViewport: !notifInner.expanded && notifInner.nonAnimHeight < notifInner.implicitHeight
            LazyListView.preferredHeight: closed ? 0 : notifInner.nonAnimHeight
            LazyListView.visibleHeight: notifInner.implicitHeight
            implicitHeight: notifInner.implicitHeight

            opacity: LazyListView.removing || closed || LazyListView.adding ? 0 : 1
            scale: LazyListView.removing || closed ? 0.6 : LazyListView.adding ? 0 : 1

            onExpandRequested: expanded => notifInner.toggleExpand(expanded)
            onCloseRequested: notif.closeAll()

            Timer {
                id: clearTimer

                // One-shot: detach-first mirrors Notifs.clear() to avoid the
                // O(n) self-removal inside NotifData.close() firing per item.
                interval: 15
                repeat: false
                triggeredOnStart: true
                onTriggered: {
                    // Collect targets, remove from list in one assignment,
                    // then close each — NotifData.close() skips its own filter
                    // path when the item is no longer in Notifs.list.
                    const toClose = Notifs.list.filter(n => !n.closed && n.appName === notif.modelData);
                    if (toClose.length === 0)
                        return;
                    Notifs.list = Notifs.list.filter(n => !toClose.includes(n));
                    Notifs.openCount = Math.max(0, Notifs.openCount - toClose.length);
                    for (const n of toClose) n.close();
                }
            }

            NotifGroup {
                id: notifInner

                modelData: notif.modelData
                props: root.props
                container: root.container
                visibilities: root.visibilities
            }
        }
    }

    Anim {
        id: contentYAnim

        target: root.container
        property: "contentY"
    }
}
