import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()

    // The tab and the calendar month are worth keeping across a shell reload, which is
    // what this id buys: a PersistentProperties without one has its values dropped when
    // Quickshell reloads the config. It has to name the screen as well - one id shared
    // by every screen would have them all reading and writing the same values.
    reloadableId: `screenState-${modelData.name}`
}
