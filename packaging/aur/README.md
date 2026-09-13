# AUR packaging

One package. It was planned as two, a shell and a CLI, and the split does not
survive contact with the code: the command's helpers are the shell's own seams
(`caelestia-shell-ipc` is meaningless without it), the palette it generates comes
from templates and a scheme catalogue that belong to the shell, and the QML calls
the command by name. One package is also the argument the lock screen got: nothing
in it can drift from the shell it locks or the command it calls.

| Package | State | Notes |
| --- | --- | --- |
| `caelestia-shell-kde` | written, waiting on the next release | the shell, the `caelestia` command and its helpers, the palette data, the Plasma lock screen, the workspace-tracker effect, autostart |
| `caelestia-cli-kde` | not needed | the command ships in the shell package. The name stays free in case the command ever earns a life without the shell |

Both names are free on the AUR (verified 2026-09-12, `resultcount` 0 for each).

## What the package installs

- the shell tree, the Caelestia QML plugin and M3Shapes, through the shell's own
  CMake install: `/etc/xdg/quickshell/caelestia`, `/usr/lib/qt6/qml`,
  `/usr/lib/caelestia`. That is the system layout upstream's package uses, so
  quickshell finds it with no per-user copy;
- `src/bin/*` into `/usr/bin`: `caelestia` and the seven helpers it drives. They
  are one surface, and the dispatcher runs its siblings from its own directory;
- `src/matugen/` and `src/schemes/` into `/usr/share/caelestia`. `caelestia-color`
  looks for them in `$CAELESTIA_DATA_DIR`, `$CAELESTIA_LIB_DIR`,
  `~/.local/lib/caelestia` and `/usr/share/caelestia`, in that order, so no
  environment variable is needed;
- `src/kde/shells/caelestia.desktop` into `/usr/share/plasma/shells`: the lock
  screen is a Plasma shell package rather than a Quickshell module, so the shell's
  CMake knows nothing about it;
- the workspace-tracker KWin effect, built here against this machine's Plasma
  because it links KWin's ABI;
- autostart: `/usr/bin/caelestia-autostart`, the systemd user unit it runs under,
  and nothing else. The unit is not enabled by the package - packages cannot enable a
  user's units - so `caelestia install` does it once.

It declares `provides=('caelestia-shell')` and
`conflicts=('caelestia-shell' 'caelestia-shell-git')`. That is honest: the QML
interface and the config directory are the same, and the community packages that
require `caelestia-shell` do so optionally, so nothing breaks.

It no longer depends on `caelestia-cli`. The color pipeline belongs to this
project now - `caelestia-color` generates the palette with matugen, applies it and
fans it out - so what the package needs from outside is `matugen` and `python`,
not another caelestia.


## Updates in a packaged install

The shell's Update page runs `caelestia-update`, and that helper decides what to do
from the directory it was installed in: `/usr/bin` is a package's, `~/.local/bin` is
the installer's. A packaged install therefore goes to the package manager instead of
doing the work below it - no repository is cloned and no second shell is built into
`~/.config` and `~/.local`, where pacman would know nothing about it and which needs
cmake, make and git that the package does not require.

So updating from the shell in a packaged install runs `pacman -Syu`, prints the line
that finishes the job (`sudo pacman -Syu caelestia-shell-kde`, or a rebuild of the AUR
package) and asks for a log out. `caelestia-check-updates` still compares the installed
version against the project's newest tag, which is what the Update row reports from -
that is why `git` is a dependency.


## Reusable path fixes a package needs

A system install puts the shell somewhere other than `$HOME`. Done on
2026-09-12:

- `Paths.bin(name)` in `shell/utils/Paths.qml` resolves a command through
  `CAELESTIA_BIN_DIR`, falling back to `~/.local/bin`. `Recorder.qml`,
  `RegionSelection.qml` and `UpdateChecker.qml` use it, and the source install's
  autostart script exports the variable the same way the package's does.
- `PluginsPage.qml`, `AppearancePage.qml`, `Toggles.qml` and `PluginLoader.qml`
  reach `restart_shell.sh` and `list-plugins.sh` through
  `Quickshell.shellPath("scripts/...")`, which follows the shell wherever it is
  installed.
- `LockScreenUi.qml` resolves the IPC helper inside the command it runs, because
  kscreenlocker inherits neither the session environment nor its PATH: the helper
  is looked up with `~/.local/bin` in front, which covers the package's
  `/usr/bin` and a source install's copy.

The two items this list used to end with are covered as well: the environment
file at `~/.config/environment.d/caelestia.conf` carries `CAELESTIA_BIN_DIR` into
the session and into the user manager, so `caelestia-shell-ipc` finds the shell
config, and the update-checker unit resolves its helper from that same variable
instead of a hardcoded `$HOME`.

## Installing

The package owns everything under `/usr` and `/etc`. What it cannot do is the
data only a user's files can hold, so installing is two steps:

    yay -S caelestia-shell-kde
    caelestia install

`caelestia install` runs the same step scripts a checkout's installer runs, for the
user's half only: the config files, the KDE settings, the user services, the
environment, the autostart unit (which it enables, because a package cannot enable
a user's units) and the wallpaper state. It is idempotent, and `caelestia update` on
a packaged install runs the package manager and then it again.


## Publishing

The AUR repository for a package is the package directory itself. For
`caelestia-shell-kde`:

    git clone ssh://aur@aur.archlinux.org/caelestia-shell-kde.git
    cp packaging/aur/caelestia-shell-kde/* caelestia-shell-kde/
    cd caelestia-shell-kde
    makepkg --printsrcinfo > .SRCINFO
    git add PKGBUILD .SRCINFO caelestia-autostart caelestia-shell.service
    git commit -m "update to 2.4.3"
    git push

Updating for a release:

1. bump `pkgver` and reset `pkgrel=1`. Nothing else needs a hash: the source is a
   git clone of the tag (`_ref` defaults to `v$pkgver`), so there is no tarball;
2. the three `sha256sums` entries that are not `SKIP` are the files beside the
   PKGBUILD, so run `makepkg -g` to refresh them if any of them changed;
3. check the tag still has everything `package()` copies by name: `src/bin/*`,
   `src/matugen/`, `src/schemes/`, `src/kde/shells/caelestia.desktop`,
   `shell/kwin-effects/workspace-tracker`, and for the user's half `scripts/`,
   `src/dots/`, `src/dots-extra/`, `src/yet-another-monochrome-icon-set/`,
   `shell/assets/wallpapers/`, `assets/org.quickshell.desktop` and
   `.github/version.env`. A missing path fails the build rather than shipping a
   package with a silent hole in it, which is why they are named;
4. regenerate `.SRCINFO` before pushing.

To build before a tag exists, `_ref=dev makepkg -si`. The version the shell reports
is still `pkgver`, so that is for testing the flow rather than for a release.

One thing to improve: cloning brings the whole history, and the tree is large. A
source archive produced by the release job - `shell/`, `scripts/`, `src/`,
`assets/` and `.github/version.env`, with the two submodules' content folded in -
would cut the download and the build time without changing the package. Until then,
`makepkg` clones the lot.

`makepkg` cannot run on the Windows host this repo is developed on, so a build
has to be tried on an Arch machine or a container before the first push.
