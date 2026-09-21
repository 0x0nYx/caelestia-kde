#!/usr/bin/env bash
detect_base_distro() {
    local detected="unknown"

    if [[ -n "${BASE_DISTRO:-}" ]]; then
        printf '%s\n' "$BASE_DISTRO"
        return 0
    fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
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

# Asks this distro's package manager whether $1 is installed. The sparsest of the
# three probes is deliberate: every caller only wants "is it already here".
package_present() {
    local pkg="$1"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Qq "$pkg" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$pkg" >/dev/null 2>&1
    elif command -v dpkg >/dev/null 2>&1; then
        dpkg -s "$pkg" >/dev/null 2>&1
    else
        return 1
    fi
}

# The Darkly GTK theme either arrives as a package or is built from source by
# darkly-gtk's install.sh, which only drops theme directories - so ask both.
darkly_gtk_installed() {
    package_present darkly-gtk && return 0
    [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/themes/Darkly" ]] ||
    [[ -d "$HOME/.themes/Darkly" ]] ||
    [[ -d "/usr/share/themes/Darkly" ]]
}

# The SDK unpacks into /usr and every caller that unpacks it needs escalation for
# that, so callers check this first: re-unpacking what is already there asks for a
# password the update does not otherwise need. Same probe as 08-build-shell.sh's
# toolchain stamp, so the two agree on when libcava is present.
cava_sdk_installed() {
    if command -v pkg-config >/dev/null 2>&1; then
        pkg-config --exists libcava 2>/dev/null && return 0
        pkg-config --exists cava 2>/dev/null && return 0
    fi
    [[ -f /usr/include/cava/cavacore.h ]]
}

linguist_tools_available() {
    local fallback="${CAELESTIA_LRELEASE_FALLBACK:-/usr/lib/qt6/bin/lrelease}"

    command -v lrelease >/dev/null 2>&1 || [[ -x "$fallback" ]]
}

install_linguist_tools() {
    if linguist_tools_available; then
        return 0
    fi

    if command -v pacman >/dev/null 2>&1; then
        caelestia_sudo pacman -S --needed --noconfirm qt6-tools
    elif command -v dnf >/dev/null 2>&1; then
        caelestia_sudo dnf install -y qt6-qttools-devel
    elif command -v apt-get >/dev/null 2>&1; then
        caelestia_sudo apt-get install -y qt6-l10n-tools qt6-tools-dev
    else
        return 1
    fi
}

install_cava_sdk() {
    local arch="${CAELESTIA_TARGET_ARCH:-}"
    if [[ -z "$arch" ]]; then
        arch="$(uname -m 2>/dev/null || echo "x86_64")"
    fi

    local distro="${1:-$(detect_base_distro)}"

    local asset_suffix
    case "$distro" in
        arch) asset_suffix="arch" ;;
        fedora) asset_suffix="fedora" ;;
        debian|ubuntu) asset_suffix="ubuntu" ;;
        *) return 1 ;;
    esac

    local url="https://github.com/ladybug-me/cava/releases/download/continuous/cava-${arch}-${asset_suffix}.tar.gz"
    local tar_cmd=(tar -C /usr -xzf - --exclude='bin')
    if [[ "$EUID" -ne 0 ]]; then
        if command -v caelestia_sudo >/dev/null 2>&1; then
            tar_cmd=(caelestia_sudo "${tar_cmd[@]}")
        elif command -v sudo >/dev/null 2>&1; then
            tar_cmd=(sudo "${tar_cmd[@]}")
        fi
    fi

    curl -fsSL "$url" | "${tar_cmd[@]}" 2>/dev/null
}
