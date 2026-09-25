pragma Singleton

import QtQuick
import qs.services

/**
 * NetworkConnection
 *
 * Centralized utility for network connection logic. Provides a single source of truth
 * for connecting to wireless networks, eliminating code duplication across
 * controlcenter components and bar popouts.
 *
 * Usage:
 * ```qml
 * import qs.utils
 *
 * // With Session object (controlcenter)
 * NetworkConnection.handleConnect(network, session);
 *
 * // Without Session object (bar popouts) - provide password dialog callback
 * NetworkConnection.handleConnect(network, null, (network) => {
 *     // Show password dialog
 *     root.passwordNetwork = network;
 *     root.showPasswordDialog = true;
 * });
 * ```
 */
QtObject {
    id: root

    property var passwordNetwork: null

    /**
     * Bring the current connection down before running connect, unless it is
     * already the target: an activation on a device that is busy with another
     * connection is left for NetworkManager to resolve otherwise.
     *
     * @param isTarget Whether the connection that is up is the one about to be connected
     * @param connect Callback that starts the connection
     */
    function disconnectFirstIfNeeded(isTarget: bool, connect: var): void {
        if (Nmcli.active && !isTarget) {
            Nmcli.disconnectFromNetwork();
            Qt.callLater(connect);
        } else {
            connect();
        }
    }

    /**
     * Handle network connection with automatic disconnection if needed.
     * If there's an active network different from the target, disconnects first,
     * then connects to the target network.
     *
     * @param network The network object to connect to (must have ssid property)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     */
    function handleConnect(network, session, onPasswordNeeded): void {
        if (!network) {
            return;
        }

        root.disconnectFirstIfNeeded(Nmcli.active?.ssid === network.ssid, () => {
            root.connectToNetwork(network, session, onPasswordNeeded);
        });
    }

    /**
     * Connect to one specific saved profile, identified by its UUID.
     *
     * The target is a saved profile rather than a scanned network: it already
     * holds its credentials, so there is no password step, and the UUID is what
     * keeps the choice unambiguous when several profiles share one SSID.
     *
     * Two profiles of one SSID are exactly the case where the connection that
     * is up is a different profile than the target, which comparing SSIDs
     * cannot see, so the active one is matched by UUID.
     *
     * @param uuid Profile UUID (required)
     * @param onResult Optional callback function(result) called with the connection result
     */
    function connectToSavedProfile(uuid, onResult): void {
        if (!uuid) {
            return;
        }

        root.disconnectFirstIfNeeded(Nmcli.active?.uuid === uuid, () => {
            Nmcli.connectToNetworkByUuid(uuid, onResult || null);
        });
    }

    /**
     * Connect to a wireless network.
     * Handles both secured and open networks, checks for saved profiles,
     * and shows password dialog if needed.
     *
     * @param network The network object to connect to (must have ssid, isSecure, bssid properties)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     */
    function connectToNetwork(network, session, onPasswordNeeded): void {
        if (!network) {
            return;
        }

        if (network.isSecure) {
            const hasSavedProfile = Nmcli.hasSavedProfile(network.ssid);

            if (hasSavedProfile) {
                Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
            } else {
                // Use password check with callback
                Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
                    if (result.needsPassword) {
                        // Clear pending connection if exists
                        if (Nmcli.pendingConnection) {
                            Nmcli.connectionCheckTimer.stop();
                            Nmcli.immediateCheckTimer.stop();
                            Nmcli.immediateCheckTimer.checkCount = 0;
                            Nmcli.pendingConnection = null;
                        }

                        // Handle password dialog - use session if available, otherwise use callback
                        if (session && session.network) {
                            session.network.showPasswordDialog = true;
                            session.network.pendingNetwork = network;
                        } else if (onPasswordNeeded) {
                            onPasswordNeeded(network);
                        }
                    }
                }, network.bssid);
            }
        } else {
            Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
        }
    }

    /**
     * Connect to a wireless network with a provided password.
     * Used by password dialogs when the user has already entered a password.
     *
     * @param network The network object to connect to (must have ssid, bssid properties)
     * @param password The password to use for connection
     * @param onResult Optional callback function(result) called with connection result
     */
    function connectWithPassword(network, password, onResult): void {
        if (!network) {
            return;
        }

        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", onResult || null);
    }
}
