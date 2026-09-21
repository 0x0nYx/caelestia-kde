#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QString>
#include <QStringList>
#include <QtGlobal>

namespace {

// QtCore's Settings elements (the ones the shell uses for blur quality, the
// launcher logo, the updater's options and the rest) build their QSettings
// storage path out of QCoreApplication's organization, domain and application
// names. Quickshell's own binary sets none of them, so every one of those
// elements resolved to ~/.config/Unknown Organization/quickshell.conf, QSettings
// refused to initialize, and the shell carried on with values that were never
// read back or written out.
//
// Doing this from QML cannot work. A binding on the shell's root object is
// evaluated once that object's eager children already exist and have been
// completed, and the Settings elements are among those children, so they have
// built their path before the binding runs. This file is part of the Caelestia
// module instead, and QML loads the module while it resolves `import Caelestia`,
// before it constructs any object of the importing file. The identifiers are
// therefore in place for every Settings element the shell creates, eager or not.
void setApplicationIdentifiers() {
    QCoreApplication::setOrganizationName(QStringLiteral("Caelestia"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("caelestia.dots"));
    QCoreApplication::setApplicationName(QStringLiteral("caelestia-shell"));
}

void registerDefaultFonts() {
    if (!QGuiApplication::instance())
        return;

    const QString shellConfig = qEnvironmentVariable("CAELESTIA_SHELL_CONFIG");
    const QString shellFonts = shellConfig.isEmpty()
                                   ? QString()
                                   : QFileInfo(shellConfig).absoluteDir().filePath(QStringLiteral("assets/fonts"));
    const QString dataHome = qEnvironmentVariable("XDG_DATA_HOME", QDir::homePath() + QStringLiteral("/.local/share"));
    const QString dataFonts = QDir(dataHome).filePath(QStringLiteral("caelestia/assets/fonts"));
    const QStringList roots = { shellFonts, dataFonts };
    const QStringList relativePaths = { QStringLiteral("SF-Pro/SF-Pro.ttf"),
        QStringLiteral("SF-Mono/SF-Mono-Regular.otf") };

    // QML FontLoader registers these families after the first shell objects can
    // already paint. Register the two defaults while the Caelestia module is
    // loading so initial text does not use a fallback family and then reflow.
    for (const QString& root : roots) {
        if (root.isEmpty())
            continue;
        for (const QString& relativePath : relativePaths) {
            const QString path = QDir(root).filePath(relativePath);
            if (QFileInfo::exists(path))
                QFontDatabase::addApplicationFont(path);
        }
    }
}

} // namespace

// Q_CONSTRUCTOR_FUNCTION rather than a plain static: the compiler cannot drop it
// as unused, and the call is visible as what it is.
Q_CONSTRUCTOR_FUNCTION(setApplicationIdentifiers)
Q_CONSTRUCTOR_FUNCTION(registerDefaultFonts)
