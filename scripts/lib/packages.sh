#!/usr/bin/env bash
# The package layer: which distro this is, whether a package is installed, and how a
# package gets installed. BASE_DISTRO is resolved once, here, and exported - every
# caller reads the same answer instead of asking a second time. Callers source
# log.sh first (the progress lines are its) and privileges.sh (escalation).
if [[ -z "${CAELESTIA_PACKAGES_SOURCED:-}" ]]; then
CAELESTIA_PACKAGES_SOURCED=1

# CAELESTIA_OS_RELEASE lets a test point the probe at a fixture rather than assert
# against whatever the machine it runs on happens to be.
detect_base_distro() {
    local detected="unknown"
    local os_release="${CAELESTIA_OS_RELEASE:-/etc/os-release}"

    if [[ -n "${BASE_DISTRO:-}" ]]; then
        printf '%s\n' "$BASE_DISTRO"
        return 0
    fi

    if [[ -f "$os_release" ]]; then
        . "$os_release"
        case "${ID:-}" in
            arch|cachyos|endeavouros|manjaro|artix)
                detected="arch"
                ;;
            fedora|nobara|bazzite|rhel|centos|almalinux|rocky)
                detected="fedora"
                ;;
            debian|ubuntu|pop|mint|kali|raspbian|elementary|zorin|deepin|devuan)
                detected="debian"
                ;;
            *)
                if echo "${ID_LIKE:-}" | grep -iq "arch"; then
                    detected="arch"
                elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then
                    detected="fedora"
                elif echo "${ID_LIKE:-}" | grep -iq -E "debian|ubuntu"; then
                    detected="debian"
                fi
                ;;
        esac
    fi

    if [[ "$detected" == "unknown" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            detected="arch"
        elif command -v dnf >/dev/null 2>&1; then
            detected="fedora"
        elif command -v apt-get >/dev/null 2>&1; then
            detected="debian"
        fi
    fi

    printf '%s\n' "$detected"
}

export BASE_DISTRO="$(detect_base_distro)"

# Asks this distro's own package manager whether $1 is installed. The distro decides
# which manager to ask: probing by "whichever tool is on PATH" answers for the wrong
# package universe on a machine that has a second manager installed alongside.
package_present() {
    local pkg="$1"
    case "$BASE_DISTRO" in
        arch) pacman -Qq "$pkg" >/dev/null 2>&1 ;;
        fedora) rpm -q "$pkg" >/dev/null 2>&1 ;;
        debian) dpkg -s "$pkg" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# Echoes the arguments that are not installed yet, one per line.
filter_missing() {
    local pkg
    for pkg in "$@"; do
        package_present "$pkg" || printf '%s\n' "$pkg"
    done
}

# Echoes the arguments that are installed, one per line.
filter_installed() {
    local pkg
    for pkg in "$@"; do
        package_present "$pkg" && printf '%s\n' "$pkg"
    done
}

record_failed_package() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    mkdir -p "$dir"
    printf '%s\n' "$1" >> "$dir/failed_packages.txt"
}

# Installs $1 with this distro's own tool, honouring CONFIRM_ARG. That variable is
# one flag or nothing at all, so it goes into an array instead of being spliced in
# bare: an unquoted ${CONFIRM_ARG:-} splits on nothing and vanishes, and a quoted one
# would hand yay an empty argument to treat as a package name.
package_install() {
    local pkg="$1"
    local -a confirm=()
    [[ -n "${CONFIRM_ARG:-}" ]] && confirm=("$CONFIRM_ARG")

    case "$BASE_DISTRO" in
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
            warn "No package manager is known for '$BASE_DISTRO'; cannot install $pkg."
            return 1
            ;;
    esac
}

# install_if_missing <pkg> [fallback-pkg...]
#
# Installs the first candidate that works, and returns 0 as soon as one does. A
# package that is already present counts as working. A candidate that fails is only
# recorded once every fallback after it has failed too: recording per attempt would
# report a package that a fallback went on to install.
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

# Upstream's install.sh only drops theme directories - it is not a package, so the
# directories are the whole answer.
darkly_gtk_installed() {
    [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/themes/Darkly" ]] ||
    [[ -d "$HOME/.themes/Darkly" ]] ||
    [[ -d "/usr/share/themes/Darkly" ]]
}

# Clones and builds the Darkly GTK theme. Returns non-zero when it did not land, so
# the caller can record the failure next to its own. The sassc build dependency is
# the caller's business: each distro asks for it the way it asks for everything else.
install_darkly_gtk_theme() {
    local tmpdir status=0
    tmpdir="$(mktemp -d)"

    if git clone --depth 1 https://github.com/wrymt/darkly-gtk "$tmpdir"; then
        (cd "$tmpdir" || exit 1; ./install.sh -l) || {
            err "Failed to install Darkly GTK theme."
            status=1
        }
    else
        err "Failed to clone Darkly GTK theme."
        status=1
    fi

    rm -rf "$tmpdir"
    return "$status"
}

fi
