pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.services
import qs.utils

/// Drives the Wi-Fi hotspot from a one-tap surface.
///
/// A one-tap surface has no name or password field, so it uses the ones kept in
/// the settings. A hotspot that has never been set up is not started: one tap
/// should not share an open network under the machine's hostname, so the refusal
/// points at the settings page, which is where an open network is a choice.
///
/// Both the utilities tile and the bar popout use this, so a failure is reported
/// once, here, rather than once per surface.
QtObject {
    id: root

    required property HotspotController controller

    function toggle(): void {
        if (root.controller.enabled) {
            root.controller.disable(root.report);
            return;
        }

        const { hotspotSsid, hotspotPassword } = GlobalConfig.services;
        if (hotspotSsid.length === 0 && hotspotPassword.length === 0) {
            Toaster.toast(qsTr("Hotspot"), qsTr("Give it a name and a password in Settings > Network > Hotspot"), "wifi_tethering");
            return;
        }

        root.controller.enable(HotspotSwitch.resolveName(hotspotSsid), hotspotPassword, root.report);
    }

    /// The name an empty setting stands for: the machine's own name, so a
    /// hotspot started without typing one is still identifiable on the network.
    static function resolveName(ssid: string): string {
        return ssid.length > 0 ? ssid : (SysInfo.hostname || "caelestia");
    }

    function report(result: var): void {
        if (!result || result.success)
            return;
        Toaster.toast(qsTr("Hotspot"), result.error || qsTr("The hotspot could not be started"), "wifi_tethering");
    }
}
