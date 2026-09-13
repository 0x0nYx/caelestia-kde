#!/usr/bin/env bash
# 10-autostart.sh  Set up autostart entries for Quickshell, and retire the
#                  daemon that used to apply the palette.
# Idempotent: overwrites .desktop files with correct content each run.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/install-kind.sh"

# Resolve the bundle root the same way the build script does, so this works
# whether the installer exports it or the script is run directly.
BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
mkdir -p "$HOME/.local/bin"

echo
echo ""
info "Setting up autostart entries"
echo ""

# Which tree the shell runs from, and where the session finds it. A checkout builds into
# the user's home and the wrapper below has to name those paths; a package puts the tree
# in /etc/xdg and the command, the plugin and the palette data in /usr, and
# 08-build-shell.sh has already written exactly those paths to the session environment.
# Writing the checkout's paths into the wrapper on such a machine is not a cosmetic
# difference: QML2_IMPORT_PATH would lose /usr/lib/qt6/qml, which is where the Caelestia
# plugin modules are, and the shell would start without them.
#
# The checkout's paths are written with $HOME escaped, so the unit resolves them when it
# runs rather than when this script does. The package's are absolute already.
if install_is_packaged; then
    SHELL_CONFIG="/etc/xdg/quickshell/caelestia/shell.qml"
    SHELL_ENTRYPOINT="$SHELL_CONFIG"
    ENTRYPOINT_HINT="the package owns this path; reinstall caelestia-shell-kde"
    WRAPPER_PATH_EXPORT='# PATH is left alone: the package puts the command in /usr/bin, which every session
# already has. Prepending ~/.local/bin would let a leftover copy from a checkout win
# over the one the package owns.'
    WRAPPER_QML_EXPORT='export QML2_IMPORT_PATH="/usr/lib/qt6/qml:/etc/xdg/quickshell/caelestia"'
    WRAPPER_LIB_EXPORT='export CAELESTIA_LIB_DIR="/usr/lib/caelestia"'
    WRAPPER_BIN_EXPORT='export CAELESTIA_BIN_DIR="/usr/bin"'
else
    SHELL_CONFIG="$HOME/.config/quickshell/caelestia/shell.qml"
    SHELL_ENTRYPOINT='$HOME/.config/quickshell/caelestia/shell.qml'
    ENTRYPOINT_HINT="run scripts/08-build-shell.sh first"
    WRAPPER_PATH_EXPORT='# The shell and the widgets it runs call the command by name, and 08-build-shell.sh
# installs it into ~/.local/bin. A session started by the display manager does not
# necessarily have that directory on PATH (this script is reached by absolute path, so
# finding it proves nothing), which is what leaves the wallpaper picker unable to change
# anything and the palette stuck on the built-in default. Put it there first, for
# everything the shell spawns.
export PATH="$HOME/.local/bin:$PATH"'
    WRAPPER_QML_EXPORT='export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"'
    WRAPPER_LIB_EXPORT='export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"'
    WRAPPER_BIN_EXPORT='export CAELESTIA_BIN_DIR="$HOME/.local/bin"'
fi

if [[ ! -f "$SHELL_CONFIG" ]]; then
    die "Caelestia Shell entrypoint not found: $SHELL_CONFIG ($ENTRYPOINT_HINT)"
fi

# Determine the path of quickshell to avoid PATH differences at login.
if command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v quickshell)"
elif command -v qs >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v qs)"
elif [ -x "/usr/bin/quickshell" ]; then
    QUICKSHELL_PATH="/usr/bin/quickshell"
elif [ -x "/usr/local/bin/quickshell" ]; then
    QUICKSHELL_PATH="/usr/local/bin/quickshell"
else
    die "Quickshell is not installed or is not available in PATH."
fi

# Caelestia Shell autostart
# Launch the shell this install produced directly, rather than through a wrapper that
# would have to guess where it ended up.
echo "  Creating Caelestia Shell autostart entry..."
cat > "$HOME/.local/bin/caelestia-autostart.sh" << EOF
#!/bin/bash
$WRAPPER_PATH_EXPORT
$WRAPPER_QML_EXPORT
$WRAPPER_LIB_EXPORT
$WRAPPER_BIN_EXPORT
export QS_NO_RELOAD_POPUP=1
export QS_DROP_EXPENSIVE_FONTS=1
export QS_DISABLE_CRASH_HANDLER=1
export QSG_RENDER_LOOP=threaded
export QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
# Self-heal Caelestia lock screen if KDE updates or kconf_update reset it
if [ -f "\$HOME/.local/share/plasma/shells/caelestia.desktop/contents/lockscreen/LockScreen.qml" ] || [ -f "/usr/share/plasma/shells/caelestia.desktop/contents/lockscreen/LockScreen.qml" ]; then
    if command -v kreadconfig6 >/dev/null 2>&1 && command -v kwriteconfig6 >/dev/null 2>&1; then
        current_shell="\$(kreadconfig6 --file plasmashellrc --group "Shell" --key "ShellPackage" 2>/dev/null || true)"
        if [ "\$current_shell" != "caelestia.desktop" ]; then
            kwriteconfig6 --file plasmashellrc --group "Shell" --key "ShellPackage" "caelestia.desktop" 2>/dev/null || true
        fi
        kwriteconfig6 --file kscreenlockerrc --group "Greeter" --key "Theme" --delete 2>/dev/null || true
    fi
fi
# No --daemonize: the autostart entry already runs under a systemd user unit,
# which supervises the process and connects its stdout/stderr to the journal.
# Detaching would replace that with /dev/null, and every application launched
# from the shell inherits those descriptors - which is how the shell was
# handing apps a stdout that goes nowhere. Vesktop deadlocks in exactly that
# state when a call starts (issue #402); reproducible outside the shell with
# \`vesktop >/dev/null 2>&1\`.
#
# Dropping it also makes the old stdbuf wrapper unnecessary: journald stdio is
# what the line-buffering hack was working around, and stdbuf leaked
# LD_PRELOAD=libstdbuf.so into every launched app on top of that.
exec "$QUICKSHELL_PATH" -n -p "$SHELL_ENTRYPOINT"
EOF
chmod +x "$HOME/.local/bin/caelestia-autostart.sh"

# The shell is started by one thing: the systemd user unit below. It replaced the
# desktop entry this script used to write, which KDE's xdg-autostart generator
# turned into app-caelestiashell@autostart.service - two mechanisms for one shell,
# and on a machine where the package installed its own entry under /etc, one of
# them had to be shadowed by the other.
#
# The ordering is what the entry's phase used to buy, and it still matters here:
# the shell registers org.freedesktop.Notifications, and applications decide once,
# when they start, whether a notification server exists - one that finds none draws
# its own popups for the rest of the session, in its own corner, ignoring every
# setting here. Before=xdg-desktop-autostart.target puts this unit in front of the
# app units that same generator creates. (On a machine without that target the
# ordering is a no-op, which is worse than the phase but never wrong.)
echo "  Creating the Caelestia Shell unit..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/caelestia-shell.service" << EOF
[Unit]
Description=Caelestia Shell
PartOf=graphical-session.target
After=graphical-session.target
Before=xdg-desktop-autostart.target

[Service]
Type=exec
ExecStart=%h/.local/bin/caelestia-autostart.sh
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

# Take the older mechanisms back out. The entry is ours, so removing it is safe;
# the unit it generated is disabled as well, or it would keep starting a shell of
# its own from the same wrapper.
if [[ -f "$AUTOSTART_DIR/caelestiashell.desktop" ]]; then
    rm -f "$AUTOSTART_DIR/caelestiashell.desktop"
    systemctl --user disable app-caelestiashell@autostart.service >/dev/null 2>&1 || true
    info "Removed the retired autostart entry; the shell's unit replaced it."
fi

systemctl --user daemon-reload
if systemctl --user enable caelestia-shell.service >/dev/null 2>&1; then
    ok "Caelestia Shell unit enabled."
else
    warn "Could not enable caelestia-shell.service; start the shell with 'systemctl --user start caelestia-shell.service'."
fi

# KWin restricts privileged Wayland protocols (like zkde_screencast_unstable_v1,
# used for live window thumbnails). For every such protocol, KWin's
# allowInterface() calls KWin::fetchRequestedInterfaces(client->executablePath()),
# which uses KApplicationTrader::query() to find an installed .desktop file whose
# Exec= *first token*, resolved via QFileInfo::canonicalFilePath(), matches the
# client's executable path *exactly* (no $PATH lookup, no symlink allowances
# beyond what canonicalFilePath() resolves, and no wrapper scripts). A desktop
# file with no Exec= line at all never matches anything (QProcess::splitCommand
# returns an empty list, so the predicate always rejects it). Create a
# user-level override at the standard XDG path, with Exec= pointing at the
# fully-resolved quickshell binary, so KWin can find it and grant the protocol.
echo "  Creating quickshell KDE Wayland interface declaration..."
mkdir -p "$HOME/.local/share/applications"
QUICKSHELL_CANONICAL_PATH="$(realpath "$QUICKSHELL_PATH")"
cat > "$HOME/.local/share/applications/quickshell.desktop" << DESKEOF
[Desktop Entry]
Type=Application
Name=Quickshell
NoDisplay=true
Exec=$QUICKSHELL_CANONICAL_PATH
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1,org_kde_plasma_window_management
DESKEOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
# KApplicationTrader/KService resolve through the ksycoca cache, not just the
# desktop-file-database used above; force a rebuild so the new Exec= is seen.
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi
ok "Quickshell Wayland interface declaration created."

#  Retired: kde-material-you-colors
#
# The palette is generated and applied by `caelestia-color` now, so nothing
# here starts that daemon. An install that predates the change still has its
# unit enabled, and it would keep applying a scheme of its own on top of the
# one we apply - whichever runs last wins - so the unit is stopped here.
echo "  Retiring the KDE Material You Colors service..."
rm -f "$AUTOSTART_DIR/kde-material-you-colors.desktop" 2>/dev/null || true

KMY_UNIT="$HOME/.config/systemd/user/kde-material-you-colors.service"
if [[ -e "$KMY_UNIT" ]]; then
    systemctl --user disable --now kde-material-you-colors.service >/dev/null 2>&1 || true
    rm -f "$KMY_UNIT"
    systemctl --user daemon-reload
    ok "kde-material-you-colors no longer applies the scheme; its service was removed."
else
    skip "kde-material-you-colors service is not installed."
fi

# KMY wrote two schemes per change to work around plasma-apply-colorscheme
# refusing the name already in effect. Ours rotates between two names of its
# own, and the ones it left behind would only be duplicates in System Settings.
rm -f "$HOME/.local/share/color-schemes/MaterialYou"*.colors 2>/dev/null || true

#  Retired: the status icons order file
#
# The bar kept the order the user dragged its status icons into in a file of its
# own under ~/.config/caelestia. The order is part of the config now
# (bar.statusIcons), where the settings editor can see it, and the shell is what
# moves it there: ConfigMigrations.qml reads the file, writes the list from its
# order and the retired switches, and deletes the file on the following start,
# once the list it fed is in the config. This script must not delete it - it runs
# on the same login as the shell does, and a file removed here would take the
# order with it before the shell has read it.
if [[ -f "$HOME/.config/caelestia/status_icons_order.txt" ]]; then
    skip "Status icon order file left to the shell, which migrates it into bar.statusIcons."
fi

# Live window thumbnails.
#
# KWin only advertises its privileged Wayland interfaces to clients whose
# desktop file requests them: it resolves the client's /proc/<pid>/exe, then
# looks for an installed .desktop whose Exec resolves to that same binary and
# reads X-KDE-Wayland-Interfaces from it. Quickshell's packaged entry has no
# Exec line at all, so the shell matches nothing and zkde_screencast_unstable_v1
# is never offered — the dock hover popup and window switcher then fall back to
# drawing the app icon instead of a live preview.
#
# Note this cannot live on the autostart entry above: KWin matches on the
# resolved executable, and that entry's Exec is the wrapper script rather than
# the quickshell binary, so it never matches.
if [[ -f "$BUNDLE_DIR/assets/org.quickshell.desktop" ]]; then
    echo "  Requesting KWin screencast interface for window previews..."
    mkdir -p "$HOME/.local/share/applications"
    sed "s|^Exec=.*|Exec=$QUICKSHELL_CANONICAL_PATH|" \
        "$BUNDLE_DIR/assets/org.quickshell.desktop" \
        > "$HOME/.local/share/applications/org.quickshell.desktop" 2>/dev/null || true
    # KWin reads this through KService, which needs its cache rebuilt.
    kbuildsycoca6 >/dev/null 2>&1 || true
    echo "  [OK]  Window preview interface requested."
fi

ok "Autostart entries configured."
