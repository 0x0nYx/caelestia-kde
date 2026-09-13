#!/usr/bin/env bash
# Build the AUR package from a checkout, before the release it names exists.
#
# The package's source is the tarball the release job attaches
# (.github/workflows/version-release.yml, job build-source). That asset does not exist
# until a tag has been pushed and the job has run, so a plain `makepkg -si` in
# packaging/aur/caelestia-kde cannot work first, and hashing a not-yet-existing URL is not
# possible either.
#
# This builds the same tarball locally - same contents, same inlined submodules, same
# exclusions, same REVISION file - and stages a copy of the PKGBUILD next to it with
# _source_url and _source_sum pointing at it. Everything else, including the compile, is
# the real package build, which is the point: this is how a release is tested before it is
# tagged.
#
#   packaging/aur/makepkg-from-checkout.sh          # build the package
#   packaging/aur/makepkg-from-checkout.sh -si      # build and install it
#   packaging/aur/makepkg-from-checkout.sh --clean  # rebuild from scratch
#
# The staged tree is $CAELESTIA_AUR_STAGE (default ~/.cache/caelestia-aur), not /tmp:
# makepkg builds the whole shell there, and a tmpfs is usually too small for it.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
pkgdir="$here/caelestia-kde"

for cmd in git makepkg tar sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "missing: $cmd" >&2; exit 1; }
done

# shellcheck source=/dev/null
pkgver="$(set +u; . "$pkgdir/PKGBUILD"; printf '%s' "$pkgver")"
[[ -n "$pkgver" ]] || { echo "could not read pkgver from $pkgdir/PKGBUILD" >&2; exit 1; }

stage="${CAELESTIA_AUR_STAGE:-$HOME/.cache/caelestia-aur}"
src="$stage/caelestia-kde-v$pkgver"
tree="$src/caelestia-kde-$pkgver"
artifact="$src/caelestia-kde-v$pkgver.tar.gz"

if [[ "${1:-}" == "--clean" ]]; then
    shift
    rm -rf "$src"
fi

mkdir -p "$src"

echo "==> staging the tree at $(git -C "$repo" rev-parse --short HEAD)"
# A fresh clone, not the working tree, and for the same three reasons the release job gets
# one: build directories and other untracked output cannot leak into the package, the
# submodules arrive at the commits this checkout pins even where they were never
# initialized, and the source can be a read-only mount or another user's directory. The
# cost is that uncommitted changes are not in the package, which is also true of a release.
rm -rf "$tree"
git clone --quiet --depth 1 --recurse-submodules --shallow-submodules "file://$repo" "$tree"

# Not built from source. The install fetches these into the user's own asset directory
# (scripts/12-fetch-assets.sh), which is why the release tarball drops them too: they are
# 308 MiB, and every build would carry them.
rm -rf "$tree/shell/assets/fonts"

# What a tree without .git has to be told: shell/CMakeLists.txt reads this before it falls
# back to git, so a shell built from the tarball reports the commit a checkout would.
git -C "$tree" rev-parse HEAD > "$tree/REVISION"

# The tarball is a source tree, not a repository: no .git (including the submodules' .git
# files) and no .gitmodules, which the inlined submodules make meaningless.
rm -rf "$tree/.git" "$tree/.gitmodules"
find "$tree" -maxdepth 4 -name '.git' -exec rm -rf {} + 2>/dev/null || true

echo "==> building $artifact"
tar -C "$src" -czf "$artifact" "caelestia-kde-$pkgver"

sum="$(sha256sum "$artifact" | cut -d' ' -f1)"

# The staged PKGBUILD is the real one with two variables set ahead of it. See the comment
# above source= in the real file for why those exist.
{
    printf '_source_url="%s"\n' "$(basename "$artifact")"
    printf '_source_sum="%s"\n' "$sum"
    cat "$pkgdir/PKGBUILD"
} > "$src/PKGBUILD"
install -m644 "$pkgdir/caelestia-autostart" "$pkgdir/caelestia-shell.service" "$src/"

echo "==> $(du -h "$artifact" | cut -f1) tarball, sha256 $sum"
echo "==> makepkg in $src"
cd "$src"
exec makepkg --force "$@"
