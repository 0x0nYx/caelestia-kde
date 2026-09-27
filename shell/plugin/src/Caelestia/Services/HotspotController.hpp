// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <NetworkManagerQt/ConnectionSettings>
#include <NetworkManagerQt/WirelessDevice>
#include <QJSValue>
#include <QObject>
#include <QString>
#include <optional>

namespace caelestia::services {

/// The Wi-Fi access point the shell can broadcast.
///
/// Owns everything about the hotspot: whether the hardware can run one, whether
/// one is currently up, and the profile it is saved as. Split out of NmQt so
/// that class is not also a second, unrelated service.
///
/// The only state is the active access point, read from NetworkManager on
/// demand. Every other fact - supported, enabled, the name it broadcasts - is
/// derived from that, so the three cannot disagree with each other.
class HotspotController : public QObject {
    Q_OBJECT

    /// Id of the profile the shell saves its access point as. Stable across
    /// sessions so a second enable updates the profile instead of adding a
    /// numbered duplicate beside it, and so Plasma's network applet shows the
    /// hotspot under a name that says where it came from.
    Q_PROPERTY(QString profileId READ profileId CONSTANT)

    /// Whether any wireless device on this machine can run an access point.
    Q_PROPERTY(bool supported READ supported NOTIFY stateChanged)

    /// Whether an access point is up, whether or not the shell started it.
    Q_PROPERTY(bool enabled READ enabled NOTIFY stateChanged)

    /// The name the active access point broadcasts, empty when there is none.
    Q_PROPERTY(QString ssid READ ssid NOTIFY stateChanged)

    /// Whether an enable or disable is in flight. Lets a switch hold off until
    /// the backend has caught up instead of guessing.
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit HotspotController(QObject* parent = nullptr);

    QString profileId() const;
    bool supported() const;
    bool enabled() const;
    QString ssid() const;
    bool busy() const;

    /// Read the access point state from NetworkManager again.
    void refresh();

    /// Turn the hotspot on, creating or updating the profile first.
    ///
    /// `ssid` is what the access point broadcasts; the caller resolves an empty
    /// one to the machine's name, which is a naming decision rather than a
    /// networking one. An empty password shares an open network; a password
    /// under eight characters is refused, because WPA cannot carry one and
    /// quietly sharing an open network instead is not what asking for a password
    /// means.
    ///
    /// callback receives the usual result object; an invalid callback is fine.
    Q_INVOKABLE void enable(const QString& ssid, const QString& password, QJSValue callback = {});

    /// Turn the hotspot off, leaving its profile saved.
    Q_INVOKABLE void disable(QJSValue callback = {});

signals:
    void stateChanged();
    void busyChanged();

    /// Emitted after a successful enable, so the saved-connection lists can be
    /// reloaded (the first enable creates a profile that was not there before).
    void profileAdded();

private:
    /// An access point that is up.
    struct Active {
        /// Object path of the active connection.
        QString path;
        /// The name it broadcasts.
        QString ssid;
    };

    /// The wireless device the hotspot can run on: the first one that advertises
    /// access point support, else null when no device can run one.
    static NetworkManager::WirelessDevice::Ptr accessPointDevice();

    /// The access point that is up, if any. Read from NetworkManager rather than
    /// cached, so a hotspot started from Plasma's applet is reported as on.
    static std::optional<Active> active();

    static NMVariantMapMap buildSettings(const QString& ssid, const QString& password, const QString& uuid);

    void setBusy(bool busy);
    void finish(QJSValue callback, bool success, const QString& output, const QString& error);

    bool m_busy = false;
};

} // namespace caelestia::services
