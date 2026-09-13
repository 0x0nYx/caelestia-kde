#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qurl.h>

namespace caelestia::images {

class IUtils : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static IUtils* create(QQmlEngine* engine, QJSEngine* jsEngine);

    Q_INVOKABLE static QUrl urlForPath(const QString& path, int fillMode);
    // There was an `animatedUrlForPath` declared here from v2.4.0 on, with no definition
    // anywhere in the tree and no caller. That is worse than dead code: a shared library
    // is allowed to keep an undefined symbol, moc's metaobject for the Q_INVOKABLE takes
    // the function's address, and the loader then refuses the whole library. The failure
    // is "Cannot load library libcaelestia-imagesplugin.so: libcaelestia-images.so:
    // undefined symbol: ...IUtils::animatedUrlForPath", it takes the QML module with it
    // (every type in it reports unavailable), the shell's config fails to load as a
    // result, and Restart=on-failure turns that into a crash loop. Nothing in the build
    // or in a QML lint can see it - only starting the shell can. If the caching provider
    // ever has to bypass itself for a GIF, add the function together with its body.
    Q_INVOKABLE static bool isGif(const QString& path);
    Q_INVOKABLE static bool isVideo(const QString& path);
    Q_INVOKABLE bool fileExists(const QString& path) const;
    Q_INVOKABLE static IUtils* getInstance();

private:
    explicit IUtils(QObject* parent = nullptr)
        : QObject(parent) {};
};

} // namespace caelestia::images
