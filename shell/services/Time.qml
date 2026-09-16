pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    // Seconds cost a 1 Hz timer for the whole shell, so the clock only runs at
    // minute precision until something on screen asks for seconds.
    readonly property bool secondsWanted: GlobalConfig.bar.clock.showSeconds || GlobalConfig.dashboard.showClockSeconds

    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    readonly property string timeStr: format(GlobalConfig.services.useTwelveHourClock ? "hh:mm:A" : "hh:mm")
    readonly property list<string> timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents[0] ?? ""
    readonly property string minuteStr: timeComponents[1] ?? ""
    readonly property string amPmStr: timeComponents[2] ?? ""

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        precision: secondsWanted ? SystemClock.Seconds : SystemClock.Minutes
    }
}
