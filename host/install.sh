#!/usr/bin/env bash
#
# host/install.sh — clone + venv on host (pass tokens, no Docker)
#
# Usage:
#   ./host/install.sh [module] [--extra zivid]
#   MODULE=other_module MODULE_EXTRA=none make install-host
#   ./host/install.sh --list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"
# shellcheck source=../common/install-common.sh
source "$REPO_ROOT/common/install-common.sh"
# shellcheck source=deps.sh
source "$SCRIPT_DIR/deps.sh"

MODULE="${MODULE:-camera_module}"
MODULE_EXTRA="${MODULE_EXTRA:-${CAMERA_EXTRA:-}}"
MODE=install
SKIP_DEPS=0
DEPS_ONLY=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [module] [options]

  module              default: camera_module (see configs/modules/)
  --extra NAME        pip extra: zivid, orbbec-linux, none, ...
  --pull              git pull only
  --skip-deps         skip apt / SDK (venv only)
  --deps-only         apt + SDK only
  --list              list module profiles
  -h, --help

Env: MODULE, MODULE_EXTRA, MODULE_DIR (override profile)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pull)      MODE=pull; shift ;;
        --skip-deps) SKIP_DEPS=1; shift ;;
        --deps-only) DEPS_ONLY=1; shift ;;
        --list)      list_modules; exit 0 ;;
        --module)    MODULE="$2"; shift 2 ;;
        --module=*)  MODULE="${1#*=}"; shift ;;
        --extra)     MODULE_EXTRA="$2"; shift 2 ;;
        --extra=*)   MODULE_EXTRA="${1#*=}"; shift ;;
        -h|--help)   usage; exit 0 ;;
        --*)         echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)
            MODULE="$1"
            shift
            ;;
    esac
done

load_module_profile "$MODULE"
[[ -n "${MODULE_EXTRA:-}" ]] || MODULE_EXTRA="${MODULE_PIP_EXTRA_DEFAULT:-}"
load_extra_profile "${MODULE_EXTRA:-}"
apply_legacy_aliases

install_venv_host() {
    ensure_uv
    cd "$MODULE_DIR"
    create_or_refresh_venv
    IFS=$'\t' read -r pip_user pip_token < <(pass_token_user "$PASS_PIP")
    echo ">> uv pip install in $MODULE_DIR (extra=${MODULE_EXTRA:-none})"
    pip_install_editable "$pip_user" "$pip_token"
    unset pip_user pip_token
}

main() {
    "$REPO_ROOT/common/setup-pass.sh" --check >/dev/null 2>&1 \
        || "$REPO_ROOT/common/setup-pass.sh"

    if (( DEPS_ONLY == 1 )); then
        install_host_deps
        echo ">> host deps OK (extra=${MODULE_EXTRA:-none})"
        return 0
    fi

    if (( SKIP_DEPS == 0 )); then
        install_host_deps
    else
        ensure_uv
    fi

    case "$MODE" in
        pull)
            clone_or_pull
            ;;
        install)
            clone_or_pull
            install_venv_host
            echo
            print_install_summary host
            ;;
    esac
}

main
