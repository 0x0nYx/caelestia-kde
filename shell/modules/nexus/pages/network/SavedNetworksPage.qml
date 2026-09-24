pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    // Disambiguator for duplicate profiles of the same SSID: the connection
    // name when it differs, else the UUID tail.
    function profileDisambiguator(profile: var): string {
        if (profile.id && profile.id !== profile.ssid)
            return profile.id;
        return (profile.uuid || "").slice(-4).toUpperCase();
    }

    title: qsTr("Saved networks")
    isSubPage: true

    Component.onCompleted: Nmcli.loadSavedConnections(() => {})

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ItemList {
            id: savedList

            showList: true
            first: true
            last: true
            placeholderIcon: "wifi_find"
            placeholderText: qsTr("No saved networks")

            model: ScriptModel {
                values: {
                    // One entry per saved profile, not per SSID, so duplicates
                    // of the same SSID stay distinguishable and actionable.
                    const profiles = [...Nmcli.savedConnectionProfiles].sort((a, b) => a.ssid.localeCompare(b.ssid) || a.id.localeCompare(b.id));
                    const counts = {};
                    for (const profile of profiles)
                        counts[profile.ssid] = (counts[profile.ssid] || 0) + 1;
                    return profiles.map(profile => ({ ...profile, duplicate: counts[profile.ssid] > 1 }));
                }
            }

            delegate: StateLayer {
                id: saved

                required property int index
                required property var modelData
                readonly property var profile: modelData
                readonly property string ssid: profile.ssid ?? ""
                readonly property bool duplicate: profile.duplicate ?? false
                readonly property var ap: Nmcli.findNetwork(ssid)
                readonly property bool isActive: profile.active ?? false

                anchors.left: savedList.list.contentItem.left
                anchors.right: savedList.list.contentItem.right
                implicitHeight: savedLayout.implicitHeight + savedLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                topLeftRadius: index === 0 ? Tokens.rounding.extraLarge : radius
                topRightRadius: index === 0 ? Tokens.rounding.extraLarge : radius
                bottomLeftRadius: index === savedList?.list.count - 1 ? Tokens.rounding.extraLarge : radius
                bottomRightRadius: index === savedList?.list.count - 1 ? Tokens.rounding.extraLarge : radius
                anchors.fill: undefined

                onClicked: {
                    root.nState.selectedNetworkSsid = saved.ssid;
                    root.nState.selectedNetworkUuid = saved.profile.uuid ?? "";
                    root.nState.networkDetailsFromSaved = true;
                    root.nState.openSubPage(3); // Shared network detail/edit sub-page
                }

                RowLayout {
                    id: savedLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: saved.ap ? Icons.getNetworkIcon(saved.ap.strength, !["", "none"].includes(saved.profile.security)) : "signal_wifi_off"
                        color: saved.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: saved.duplicate ? qsTr("%1 (%2)").arg(saved.ssid).arg(root.profileDisambiguator(saved.profile)) : saved.ssid
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                let security;
                                if (saved.ap)
                                    security = saved.ap.security || qsTr("Open");
                                else
                                    security = Nmcli.securityLabel(saved.profile.security) || qsTr("Unknown");
                                if (saved.isActive)
                                    return qsTr("Connected • %1").arg(security);
                                return security;
                            }
                            color: saved.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    MaterialIcon {
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }
        }
    }
}
