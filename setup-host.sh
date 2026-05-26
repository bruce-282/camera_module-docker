#!/usr/bin/env bash
#
# setup-host.sh — new Ubuntu dev PC: apt, Docker/buildx, NVIDIA, pass, make build
#
# Usage:
#   ./setup-host.sh                          full setup (interactive)
#   ./setup-host.sh --gpg-key ~/gpg-private.asc
#   ./setup-host.sh --skip-build             host + pass only
#   ./setup-host.sh --skip-nvidia            no nvidia-container-toolkit
#   ./setup-host.sh --check                  verify host + pass + docker
#
# Prereqs:
#   Ubuntu 22.04 amd64, sudo, team GPG private key (gpg-private.asc on USB/old PC)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SKIP_BUILD=0
SKIP_NVIDIA=0
GPG_KEY=""
MODE=setup

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)        MODE=check; shift ;;
        --skip-build)   SKIP_BUILD=1; shift ;;
        --skip-nvidia)  SKIP_NVIDIA=1; shift ;;
        --gpg-key)
            shift
            GPG_KEY="${1:?--gpg-key requires path}"
            shift
            ;;
        --gpg-key=*)    GPG_KEY="${1#*=}"; shift ;;
        -h|--help)
            sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (try --help)" >&2
            exit 2
            ;;
    esac
done

need_sudo() {
    sudo -n true 2>/dev/null || true
    if ! sudo -v; then
        echo "ERROR: sudo required" >&2
        exit 1
    fi
}

warn_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" != ubuntu ]] || [[ "${VERSION_ID:-}" != 22.04 ]]; then
            echo "WARN: tested on Ubuntu 22.04; you have ${PRETTY_NAME:-unknown}" >&2
        fi
    fi
}

install_apt_packages() {
    need_sudo
    local pkgs=(docker.io docker-buildx pass gnupg git clinfo)
    if (( SKIP_NVIDIA == 0 )); then
        pkgs+=(nvidia-container-toolkit)
    fi
    echo ">> apt install: ${pkgs[*]}"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

ensure_docker_running() {
    if docker info >/dev/null 2>&1; then
        echo ">> docker OK"
        return 0
    fi
    need_sudo
    echo ">> starting docker"
    sudo systemctl enable --now docker
    sleep 1
    docker info >/dev/null 2>&1 || {
        echo "ERROR: docker not running" >&2
        exit 1
    }
}

ensure_docker_group() {
    if groups | grep -q '\bdocker\b'; then
        echo ">> user in docker group"
        return 0
    fi
    need_sudo
    echo ">> adding $USER to docker group (log out/in or: newgrp docker)"
    sudo usermod -aG docker "$USER"
    if ! docker info >/dev/null 2>&1; then
        echo "WARN: docker still needs new group — run: newgrp docker" >&2
        echo "      then re-run: ./setup-host.sh --check" >&2
    fi
}

fix_buildx_plugin() {
    local user_plugin="${HOME}/.docker/cli-plugins/docker-buildx"
    if [[ -x "$user_plugin" ]]; then
        local ver
        ver="$("$user_plugin" version 2>/dev/null | head -1 || true)"
        if [[ "$ver" == *"v0.12."* ]] || [[ "$ver" == *"v0.1"* && "$ver" != *"v0.30"* ]]; then
            echo ">> backing up old user buildx plugin"
            mv "$user_plugin" "${user_plugin}.bak.$(date +%Y%m%d)"
        fi
    fi
    if ! docker buildx version >/dev/null 2>&1; then
        echo "ERROR: docker buildx not working after apt install" >&2
        exit 1
    fi
    echo ">> $(docker buildx version | head -1)"
    if docker buildx ls 2>&1 | grep -q 'driver not connecting'; then
        echo "ERROR: buildx still incompatible with docker — remove ~/.docker/cli-plugins/docker-buildx*" >&2
        exit 1
    fi
}

setup_nvidia_container() {
    if (( SKIP_NVIDIA == 1 )); then
        echo ">> skipping nvidia-container-toolkit"
        return 0
    fi
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo ">> nvidia-smi not found; skipping nvidia-container-toolkit config"
        return 0
    fi
    need_sudo
    echo ">> configuring nvidia-container-toolkit"
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    echo ">> GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || nvidia-smi -L | head -1)"
}

check_host_opencl() {
    if ! command -v clinfo >/dev/null 2>&1; then
        echo "WARN: clinfo not installed" >&2
        return 0
    fi
    if clinfo -l 2>/dev/null | grep -q .; then
        echo ">> host OpenCL:"
        clinfo -l | sed 's/^/     /'
    elif command -v nvidia-smi >/dev/null 2>&1; then
        echo "WARN: NVIDIA GPU present but clinfo shows no platform — check drivers" >&2
    fi
}

import_gpg_key() {
    local key_path=$1
    [[ -f "$key_path" ]] || { echo "ERROR: GPG key not found: $key_path" >&2; exit 1; }
    echo ">> gpg --import $key_path"
    gpg --import "$key_path"
}

prompt_gpg_import() {
    local store_dir="${PASSWORD_STORE:-$HOME/.password-store}"
    if [[ -f "${store_dir}/.gpg-id" ]] && "$SCRIPT_DIR/setup-pass.sh" --check >/dev/null 2>&1; then
        return 0
    fi
    if [[ -n "$GPG_KEY" ]]; then
        import_gpg_key "$GPG_KEY"
        return 0
    fi
    mapfile -t secs < <(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | awk -F/ '/^sec/ {print $2}' | awk '{print $1}')
    if [[ ${#secs[@]} -gt 0 ]] && "$SCRIPT_DIR/setup-pass.sh" --check >/dev/null 2>&1; then
        return 0
    fi
    echo
    echo "Team password-store needs your GPG private key (gpg-private.asc from old PC / USB)."
    echo "  scp user@old-pc:~/gpg-private.asc ~/Downloads/gpg-private.asc"
    read -rp "Path to gpg-private.asc (Enter to skip): " GPG_KEY
    [[ -z "${GPG_KEY// }" ]] && return 0
    import_gpg_key "$GPG_KEY"
}

run_setup_pass() {
    "$SCRIPT_DIR/setup-pass.sh"
}

run_build() {
    if (( SKIP_BUILD == 1 )); then
        echo ">> skipping make build (--skip-build)"
        return 0
    fi
    if ! docker info >/dev/null 2>&1; then
        echo "WARN: docker not usable (docker group?) — run: newgrp docker && make build" >&2
        return 0
    fi
    make build
}

check_all() {
    local ok=1
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo ">> OK: docker" || { echo "ERROR: docker" >&2; ok=0; }
    docker buildx ls 2>/dev/null | grep -q running && echo ">> OK: buildx" || { echo "ERROR: buildx" >&2; ok=0; }
    "$SCRIPT_DIR/setup-pass.sh" --check || ok=0
    check_host_opencl
    if docker image inspect cmes/camera-module:dev >/dev/null 2>&1; then
        echo ">> OK: image cmes/camera-module:dev"
    else
        echo "WARN: image not built yet — run: make build" >&2
    fi
    (( ok )) || exit 1
    echo ">> check OK"
}

main() {
    warn_ubuntu
    case "$MODE" in
        check) check_all ;;
        setup)
            install_apt_packages
            fix_buildx_plugin
            ensure_docker_running
            ensure_docker_group
            setup_nvidia_container
            prompt_gpg_import
            run_setup_pass
            check_host_opencl
            run_build
            echo
            echo ">> Done. Zivid in container: ./run_container.sh --gpu"
            if ! groups | grep -q '\bdocker\b'; then
                echo ">> If docker permission denied: newgrp docker   (or re-login)"
            fi
            ;;
    esac
}

main
