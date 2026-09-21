#!/usr/bin/env bash
# Installing a single package on whatever distro we are on, for the step scripts
# that only need a handful of them (07-kde-apps, 11-optional-apps). The distro
# split lives here so every caller shares one copy of it. Callers source log.sh
# first - the progress lines are its.
if [[ -z "${CAELESTIA_PACKAGE_INSTALL_SOURCED:-}" ]]; then
CAELESTIA_PACKAGE_INSTALL_SOURCED=1

# shellcheck source=scripts/lib/toolchain.sh
source "$(dirname "${BASH_SOURCE[0]}")/toolchain.sh"

record_failed_package() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    mkdir -p "$dir"
    printf '%s\n' "$1" >> "$dir/failed_packages.txt"
}

# Installs $1 with this distro's own tool, honouring CONFIRM_ARG. That variable
# is one flag or nothing at all, so it goes into an array instead of being
# spliced in bare: an unquoted ${CONFIRM_ARG:-} splits on nothing and vanishes,
# and a quoted one would hand yay an empty argument to treat as a package name.
package_install() {
    local pkg="$1"
    local -a confirm=()
    [[ -n "${CONFIRM_ARG:-}" ]] && confirm=("$CONFIRM_ARG")

    case "$(detect_base_distro)" in
        arch)
            yay -S --needed "${confirm[@]}" "$pkg" 2>/dev/null ||
                caelestia_sudo pacman -S --needed "${confirm[@]}" "$pkg" 2>/dev/null
            ;;
        fedora)
            caelestia_sudo dnf install -y "$pkg" 2>/dev/null
            ;;
        debian)
            caelestia_sudo apt-get install -y "$pkg" 2>/dev/null
            ;;
        *)
            warn "No package manager is known for this distro; cannot install $pkg."
            return 1
            ;;
    esac
}

# install_if_missing <pkg> [fallback-pkg...]
#
# Installs the first candidate that works, and returns 0 as soon as one does. A
# package that is already present counts as working. A candidate that fails is
# only recorded once every fallback after it has failed too: recording per
# attempt would report a package that a fallback went on to install.
install_if_missing() {
    local pkg
    local -a failed=()

    for pkg in "$@"; do
        if package_present "$pkg"; then
            skip "$pkg already installed."
            return 0
        fi

        info "Installing $pkg..."
        if package_install "$pkg"; then
            ok "$pkg installed."
            return 0
        fi

        warn "Could not install $pkg, skipping."
        failed+=("$pkg")
    done

    for pkg in "${failed[@]}"; do
        record_failed_package "$pkg"
    done
    return 1
}

fi
