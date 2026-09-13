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
- autostart: the desktop entry, the systemd user unit, and
  `/usr/bin/caelestia-autostart`, which sets the environment the shell needs.

It declares `provides=('caelestia-shell')` and
`conflicts=('caelestia-shell' 'caelestia-shell-git')`. That is honest: the QML
interface and the config directory are the same, and the community packages that
require `caelestia-shell` do so optionally, so nothing breaks.

It no longer depends on `caelestia-cli`. The color pipeline belongs to this
project now - `caelestia-color` generates the palette with matugen, applies it and
fans it out - so what the package needs from outside is `matugen` and `python`,
not another caelestia.


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

Still open:

- `src/bin/caelestia-shell-ipc` resolves the shell config as
  `$HOME/.config/quickshell/caelestia/shell.qml` unless `CAELESTIA_SHELL_CONFIG`
  is set. The packaged autostart sets it; the lock screen and anything else
  running outside that environment does not.
- `src/systemd/caelestia-update-checker.service` runs
  `%h/.local/bin/caelestia-check-updates`, a path only a source install has. It
  gets the same resolution when the environment work lands: a user unit can read
  `CAELESTIA_BIN_DIR` from the session environment once it is written to
  `~/.config/environment.d/`.

## Publishing

The AUR repository for a package is the package directory itself. For
`caelestia-shell-kde`:

    git clone ssh://aur@aur.archlinux.org/caelestia-shell-kde.git
    cp packaging/aur/caelestia-shell-kde/* caelestia-shell-kde/
    cd caelestia-shell-kde
    makepkg --printsrcinfo > .SRCINFO
    git add PKGBUILD .SRCINFO caelestia-autostart caelestiashell.desktop caelestia-shell.service
    git commit -m "update to 2.4.2"
    git push

Updating for a release:

1. bump `pkgver` and reset `pkgrel=1`. It currently sits one release ahead of the
   published tag on purpose, so the tarball's `sha256sums` entry is `SKIP` until
   that tag exists;
2. download
   `https://github.com/ladybug-me/caelestia-kde/archive/refs/tags/v<pkgver>.tar.gz`
   and put its sha256 in the first `sha256sums` entry;
3. the other three sums are the files beside the PKGBUILD, so run `makepkg -g`
   to refresh them all at once;
4. check the tag still has everything `package()` copies by name: `src/bin/*`,
   `src/matugen/`, `src/schemes/`, `src/kde/shells/caelestia.desktop` and
   `shell/kwin-effects/workspace-tracker`. A missing path fails the build rather
   than shipping a package with a silent hole in it, which is why they are named;
5. regenerate `.SRCINFO` before pushing.

One thing to improve: the tag archive is 271 MB, most of it assets the shell package
does not install (wallpapers, the monochrome icon set, the bundled fonts). A source
tarball produced by the release job, containing `shell/` and `.github/version.env`
only, would cut the download and the build time without changing anything about the
package. Until then, `makepkg` downloads the whole tree.

`makepkg` cannot run on the Windows host this repo is developed on, so a build
has to be tried on an Arch machine or a container before the first push.
