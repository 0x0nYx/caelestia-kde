# AUR packaging

Two packages are planned. One is written and can be published; the other is
blocked, for a reason worth writing down.

| Package | State | Notes |
| --- | --- | --- |
| `caelestia-shell-kde` | written, ready to publish | the shell: Quickshell config, Caelestia QML plugin, M3Shapes, helper commands, autostart |
| `caelestia-cli-kde` | blocked | needs the `caelestia` name and the color pipeline; see below |

Names append `kde` to the upstream package names, and both are free on the AUR
(verified 2026-09-12, `resultcount` 0 for each).

## caelestia-shell-kde

Builds `shell/` from the release tag's source archive with CMake and installs to
the same system layout upstream's package uses, so quickshell finds it without a
per-user copy: `/etc/xdg/quickshell/caelestia`, `/usr/lib/caelestia`,
`/usr/lib/qt6/qml`.

It declares `provides=('caelestia-shell')` and
`conflicts=('caelestia-shell' 'caelestia-shell-git')`. That is honest: the QML
interface and the config directory are the same, and the community packages that
require `caelestia-shell` do so optionally, so nothing breaks.

It still depends on the upstream `caelestia-cli`, exactly as upstream's shell
does, because that package provides the color pipeline and the `caelestia`
command the QML calls. This dependency is the reason the second package cannot
ship yet.

## Why caelestia-cli-kde is blocked

Our command installs `/usr/bin/caelestia`. So does upstream's `caelestia-cli`.
Two packages cannot own the same path, so `caelestia-cli-kde` has to either
conflict with `caelestia-cli` and drop it, or not be published at all.

Conflicting is fine only if our command can do everything the shell asks of it.
Today it cannot: `caelestia wallpaper` and `caelestia scheme` hand off to the
upstream CLI, because the color pipeline (`score`, `gen_scheme`, the harmonizing
and templating fan-out) is still upstream's. Conflict on day one and the dynamic
palette stops working; the shell falls back to its built-in scheme.

Two ways out, both real work:

1. Own the pipeline. Port generation and state (`scheme.json`, the wallpaper
   path, the thumbnail), which is the option the parity map settled on, and drop
   the delegation. This keeps our command and needs no upstream package.
2. Vendor the upstream CLI into this repo, the way `shell/` is vendored: carry
   its Python source and data under a private path, ship it inside
   `caelestia-cli-kde`, and have our command call it directly. This is faster,
   but it means shipping third-party GPL-3.0-only code inside our package, which
   then has to declare `GPL-3.0-only` rather than `-or-later`.

Until one of those lands, installing `caelestia-shell-kde` gives a working shell
with the upstream CLI providing the command and the palette.

## Reusable path fixes a package needs

A system install puts the shell somewhere other than `$HOME`, and a few paths
are still written out by hand for a source install. These are the changes the
package assumes, and they are the next piece of work:

- `shell/modules/nexus/pages/PluginsPage.qml`,
  `shell/modules/nexus/pages/wallandstyle/AppearancePage.qml` and
  `shell/modules/utilities/cards/Toggles.qml` call `restart_shell.sh` through
  `${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia/scripts/`. Every other
  call site already uses `Quickshell.shellPath("scripts/...")`, which follows
  the shell wherever it is installed.
- `shell/services/Recorder.qml`,
  `shell/modules/screenshot/regionSelector/RegionSelection.qml` and
  `src/kde/shells/caelestia.desktop/contents/lockscreen/LockScreenUi.qml` point
  at `~/.local/bin/caelestia-*`. The package installs those to `/usr/bin`, so
  they need to resolve like the rest.
- `src/bin/caelestia-shell-ipc` resolves the shell config as
  `$HOME/.config/quickshell/caelestia/shell.qml` unless `CAELESTIA_SHELL_CONFIG`
  is set. It needs the system path as a fallback for the lock screen and any
  other caller that runs outside the autostart environment.

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

1. bump `pkgver` and reset `pkgrel=1`;
2. download
   `https://github.com/ladybug-me/caelestia-kde/archive/refs/tags/v<pkgver>.tar.gz`
   and put its sha256 in the first `sha256sums` entry;
3. the other three sums are the files beside the PKGBUILD, so run `makepkg -g`
   to refresh them all at once;
4. regenerate `.SRCINFO` before pushing.

One thing to improve: the tag archive is 271 MB, most of it assets the shell package
does not install (wallpapers, the monochrome icon set, the bundled fonts). A source
tarball produced by the release job, containing `shell/` and `.github/version.env`
only, would cut the download and the build time without changing anything about the
package. Until then, `makepkg` downloads the whole tree.

`makepkg` cannot run on the Windows host this repo is developed on, so a build
has to be tried on an Arch machine or a container before the first push.
