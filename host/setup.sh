#!/usr/bin/env bash
#
# host/setup.sh — pass + apt + module install on host (no Docker)
#
# Usage:
#   ./host/setup.sh [--module camera_module] [--extra zivid]
#   make setup-host-native

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"
# shellcheck source=deps.sh
source "$SCRIPT_DIR/deps.sh"

MODULE="${MODULE:-camera_module}"
MODULE_EXTRA="${MODULE_EXTRA:-${CAMERA_EXTRA:-}}"
SKIP_INSTALL=0
GPG_KEY=""
MODE=setup

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)        MODE=check; shift ;;
        --skip-install) SKIP_INSTALL=1; shift ;;
        --module)       MODULE="$2"; shift 2 ;;
        --module=*)     MODULE="${1#*=}"; shift ;;
        --extra)        MODULE_EXTRA="$2"; shift 2 ;;
        --extra=*)      MODULE_EXTRA="${1#*=}"; shift ;;
        --gpg-key)
            shift
            GPG_KEY="${1:?--gpg-key requires path}"
            shift
            ;;
        --gpg-key=*)    GPG_KEY="${1#*=}"; shift ;;
        -h|--help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1 (try --help)" >&2
            exit 2
            ;;
    esac
done

load_module_profile "$MODULE"
[[ -n "${MODULE_EXTRA:-}" ]] || MODULE_EXTRA="${MODULE_PIP_EXTRA_DEFAULT:-}"
load_extra_profile "${MODULE_EXTRA:-}"
apply_legacy_aliases

warn_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" != ubuntu ]] || [[ "${VERSION_ID:-}" != 22.04 ]]; then
            echo "WARN: tested on Ubuntu 22.04; you have ${PRETTY_NAME:-unknown}" >&2
        fi
    fi
}

import_gpg_key() {
    local key_path=$1
    [[ -f "$key_path" ]] || { echo "ERROR: GPG key not found: $key_path" >&2; exit 1; }
    echo ">> gpg --import $key_path"
    gpg --import "$key_path"
}

prompt_gpg_import() {
    if "$REPO_ROOT/common/setup-pass.sh" --check >/dev/null 2>&1; then
        return 0
    fi
    if [[ -n "$GPG_KEY" ]]; then
        import_gpg_key "$GPG_KEY"
        return 0
    fi
    echo
    echo "Team password-store needs your GPG private key (gpg-private.asc)."
    read -rp "Path to gpg-private.asc (Enter to skip): " GPG_KEY
    [[ -z "${GPG_KEY// }" ]] && return 0
    import_gpg_key "$GPG_KEY"
}

check_host_opencl() {
    if command -v clinfo >/dev/null 2>&1 && clinfo -l 2>/dev/null | grep -q .; then
        echo ">> host OpenCL:"
        clinfo -l | sed 's/^/     /'
    elif command -v nvidia-smi >/dev/null 2>&1; then
        echo "WARN: NVIDIA GPU present but clinfo shows no platform — check drivers" >&2
    fi
}

check_all() {
    local ok=1
    "$REPO_ROOT/common/setup-pass.sh" --check || ok=0
    command -v uv >/dev/null 2>&1 && echo ">> OK: uv" || { echo "ERROR: uv" >&2; ok=0; }
    if [[ "${HOST_INSTALL_ZIVID_SDK:-0}" == "1" ]]; then
        dpkg-query -W -f='${Status}' zivid 2>/dev/null | grep -q "install ok installed" \
            && echo ">> OK: zivid SDK" || { echo "ERROR: zivid SDK" >&2; ok=0; }
    fi
    if [[ -x "${MODULE_DIR}/.venv/bin/python" ]]; then
        echo ">> OK: ${MODULE_DIR}/.venv"
    else
        echo "WARN: run: make install-host MODULE=$MODULE" >&2
    fi
    check_host_opencl
    (( ok )) || exit 1
    echo ">> check OK"
}

main() {
    warn_ubuntu
    case "$MODE" in
        check) check_all ;;
        setup)
            install_host_deps
            prompt_gpg_import
            "$REPO_ROOT/common/setup-pass.sh"
            check_host_opencl
            if (( SKIP_INSTALL == 0 )); then
                MODULE="$MODULE" MODULE_EXTRA="$MODULE_EXTRA" \
                    "$SCRIPT_DIR/install.sh" "$MODULE" --extra "${MODULE_EXTRA:-}" --skip-deps
            fi
            echo ">> Done."
            print_install_summary host
            ;;
    esac
}

main "$@"
