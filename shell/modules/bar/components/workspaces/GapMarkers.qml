pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

/// Hairlines in the gaps of the workspaces strip, marking where it is hiding a
/// desktop between two pills. One marker per pill, drawn in the gap before it.
Item {
    id: root

    /// The strip's live pills, in strip order.
    required property var workspaces
    /// Gap the strip leaves between pills.
    required property int wsSpacing
    required property bool isHorizontal

    AnimatedRepeater {
        model: ScriptModel {
            values: root.workspaces
        }

        removeDuration: Tokens.anim.durations.expressiveDefaultEffects

        StyledRect {
            id: marker

            required property int index
            required property Workspace modelData

            /// A marker only belongs in a gap the strip made by leaving a
            /// desktop out, which is the case when the pill before this one is
            /// not the desktop right before it. It also slides out of the way of
            /// the active pill, whose indicator grows into that gap, and of the
            /// pill the active one just left.
            property real shift: {
                if (!modelData || index === 0)
                    return 0;
                if (modelData.isActive)
                    return -root.wsSpacing / 2 - 1;
                return (root.workspaces[index - 1]?.isActive ?? false) ? root.wsSpacing / 2 : 0;
            }

            anchors.top: root.isHorizontal ? parent?.top : undefined
            anchors.bottom: root.isHorizontal ? parent?.bottom : undefined
            anchors.left: root.isHorizontal ? undefined : parent?.left
            anchors.right: root.isHorizontal ? undefined : parent?.right
            anchors.margins: Tokens.padding.extraSmall

            x: root.isHorizontal && modelData ? modelData.x - root.wsSpacing / 2 + shift : 0
            y: !root.isHorizontal && modelData ? modelData.y - root.wsSpacing / 2 + shift : 0
            implicitWidth: root.isHorizontal ? 1 : 0
            implicitHeight: root.isHorizontal ? 0 : 1
            color: Colours.palette.m3outline

            opacity: AnimatedRepeater.adding || AnimatedRepeater.removing || !modelData || index === 0 || root.workspaces[index - 1]?.ws === modelData?.ws - 1 ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on shift {
                Anim {}
            }
        }
    }
}
