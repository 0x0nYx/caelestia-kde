// SPDX-License-Identifier: GPL-3.0-only
#include "launcherentry.hpp"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QLoggingCategory>
#include <cmath>

namespace caelestia::services {

namespace {

Q_LOGGING_CATEGORY(logLauncherEntry, "caelestia.services.launcherentry");

constexpr auto kUnityService = "com.canonical.Unity";
constexpr auto kUnityInterface = "com.canonical.Unity.LauncherEntry";

QString normaliseAppId(QString id) {
    const qsizetype scheme = id.indexOf(QStringLiteral("://"));
    if (scheme >= 0)
        id = id.mid(scheme + 3);

    if (id.endsWith(QStringLiteral(".desktop"), Qt::CaseInsensitive))
        id.chop(8);

    return id;
}

QVariantMap restingEntry() {
    return {
        { QStringLiteral("known"), false },
        { QStringLiteral("count"), 0 },
        { QStringLiteral("countVisible"), false },
        { QStringLiteral("progress"), 0.0 },
        { QStringLiteral("progressVisible"), false },
        { QStringLiteral("urgent"), false },
    };
}

QVariantMap resolveEntry(const QVariantMap& properties) {
    QVariantMap entry = restingEntry();
    entry[QStringLiteral("known")] = true;

    const qlonglong count = properties.value(QStringLiteral("count")).toLongLong();
    const double progress = properties.value(QStringLiteral("progress")).toDouble();

    entry[QStringLiteral("count")] = QVariant(count > 0 ? count : 0);
    entry[QStringLiteral("countVisible")] = properties.value(QStringLiteral("count-visible")).toBool();
    entry[QStringLiteral("progress")] = QVariant(std::isfinite(progress) ? qBound(0.0, progress, 1.0) : 0.0);
    entry[QStringLiteral("progressVisible")] = properties.value(QStringLiteral("progress-visible")).toBool();
    entry[QStringLiteral("urgent")] = properties.value(QStringLiteral("urgent")).toBool();

    return entry;
}

} // namespace

LauncherEntry::LauncherEntry(QObject* parent)
    : QObject(parent)
    , m_watcher(new QDBusServiceWatcher(this)) {

    QDBusConnection bus = QDBusConnection::sessionBus();

    if (!bus.connect(QString(), QString(), QString::fromLatin1(kUnityInterface), QStringLiteral("Update"), this,
            SLOT(onUpdate(QString, QVariantMap)))) {
        qCWarning(logLauncherEntry) << "Failed to watch for" << kUnityInterface << "updates";
        return;
    }

    m_watcher->setConnection(bus);
    m_watcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_watcher, &QDBusServiceWatcher::serviceUnregistered, this, &LauncherEntry::onServiceUnregistered);

    QDBusConnectionInterface* iface = bus.interface();
    if (!iface) {
        qCWarning(logLauncherEntry) << "No session bus to own" << kUnityService << "on";
        return;
    }

    iface->registerService(QString::fromLatin1(kUnityService), QDBusConnectionInterface::DontQueueService,
        QDBusConnectionInterface::AllowReplacement);

    const QDBusReply<QString> owner = iface->serviceOwner(QString::fromLatin1(kUnityService));
    if (!owner.isValid() || owner.value() != bus.baseService())
        qCWarning(logLauncherEntry) << "Another process owns" << kUnityService
                                    << "- an entry published before the name last changed hands is not seen here";
}

int LauncherEntry::revision() const {
    return m_revision;
}

QVariantMap LauncherEntry::forApp(const QString& desktopId) const {
    const auto found = m_entries.constFind(normaliseAppId(desktopId));
    return found == m_entries.constEnd() ? restingEntry() : *found;
}

void LauncherEntry::onUpdate(const QString& appUri, const QVariantMap& properties) {
    const QString appId = normaliseAppId(appUri);
    if (appId.isEmpty())
        return;

    const QString sender = calledFromDBus() ? message().service() : QString();

    if (!sender.isEmpty() && !m_sources.contains(sender))
        m_watcher->addWatchedService(sender);

    Source& source = m_sources[sender][appId];
    for (auto property = properties.constBegin(); property != properties.constEnd(); ++property)
        source.properties.insert(property.key(), property.value());
    source.stamp = ++m_stamp;

    resolve();
}

void LauncherEntry::onServiceUnregistered(const QString& service) {
    if (m_sources.remove(service) == 0)
        return;

    m_watcher->removeWatchedService(service);
    resolve();
}

void LauncherEntry::resolve() {
    QHash<QString, QPair<quint64, QString>> newest;
    for (auto sender = m_sources.constBegin(); sender != m_sources.constEnd(); ++sender) {
        for (auto source = sender->constBegin(); source != sender->constEnd(); ++source) {
            const auto current = newest.constFind(source.key());
            if (current == newest.constEnd() || current->first < source->stamp)
                newest.insert(source.key(), { source->stamp, sender.key() });
        }
    }

    QHash<QString, QVariantMap> entries;
    entries.reserve(newest.size());
    for (auto entry = newest.constBegin(); entry != newest.constEnd(); ++entry) {
        const auto sender = m_sources.constFind(entry.value().second);
        if (sender == m_sources.constEnd())
            continue;

        const auto source = sender->constFind(entry.key());
        if (source != sender->constEnd())
            entries.insert(entry.key(), resolveEntry(source->properties));
    }

    m_entries = entries;

    ++m_revision;
    emit changed();
}

} // namespace caelestia::services
