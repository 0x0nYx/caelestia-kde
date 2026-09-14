#include <QCoreApplication>
#include <QString>
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

} // namespace

// Q_CONSTRUCTOR_FUNCTION rather than a plain static: the compiler cannot drop it
// as unused, and the call is visible as what it is.
Q_CONSTRUCTOR_FUNCTION(setApplicationIdentifiers)
