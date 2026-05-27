# host/deps.sh — apt + extra-specific SDK on Ubuntu 22.04

ZIVID_SDK_RELEASE="${ZIVID_SDK_RELEASE:-2.15.0+5fcc365b-1}"

host_need_sudo() {
    sudo -n true 2>/dev/null || true
    if ! sudo -v; then
        echo "ERROR: sudo required" >&2
        exit 1
    fi
}

ensure_uv() {
    if command -v uv >/dev/null 2>&1; then
        echo ">> uv OK ($(uv --version))"
        return 0
    fi
    echo ">> installing uv → ~/.local/bin"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${HOME}/.local/bin" sh
    export PATH="${HOME}/.local/bin:${PATH}"
    command -v uv >/dev/null 2>&1 || {
        echo "ERROR: uv not on PATH — add ~/.local/bin to PATH" >&2
        exit 1
    }
}

install_zivid_sdk() {
    if dpkg-query -W -f='${Status}' zivid 2>/dev/null | grep -q "install ok installed"; then
        echo ">> Zivid SDK already installed"
        return 0
    fi
    host_need_sudo
    local deb="zivid_${ZIVID_SDK_RELEASE}_amd64.deb"
    local url="https://downloads.zivid.com/sdk/releases/${ZIVID_SDK_RELEASE}/u22/amd64/${deb}"
    local tmp
    tmp="$(mktemp -d)"
    echo ">> installing Zivid SDK ${ZIVID_SDK_RELEASE}"
    wget -q -O "${tmp}/${deb}" "$url"
    sudo apt-get install -y "${tmp}/${deb}"
    rm -rf "$tmp"
}

install_host_apt_packages() {
    host_need_sudo
    local pkgs=(
        git ca-certificates curl wget
        build-essential pkg-config
        python3.10 python3.10-venv python3-dev
        libusb-1.0-0 libusb-1.0-0-dev libudev1
        libgl1 libglib2.0-0
        ocl-icd-libopencl1 clinfo
        pass gnupg
    )
    echo ">> apt install: ${pkgs[*]}"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_extra_host_deps() {
    if [[ "${HOST_INSTALL_ZIVID_SDK:-0}" == "1" ]]; then
        install_zivid_sdk
    fi
}

install_host_deps() {
    install_host_apt_packages
    ensure_uv
    install_extra_host_deps
}
