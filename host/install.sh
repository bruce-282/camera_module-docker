#!/usr/bin/env bash
#
# host/install.sh — clone + venv on host (pass tokens, no Docker)
#
# Usage:
#   ./host/install.sh
#   ./host/install.sh --pull
#   make install-host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/install-common.sh
source "$REPO_ROOT/common/install-common.sh"
# shellcheck source=deps.sh
source "$SCRIPT_DIR/deps.sh"

CAMERA_MODULE_DIR="${CAMERA_MODULE_DIR:-$HOME/camera_module}"
CAMERA_REPO="${CAMERA_REPO:-gitlab.cmes-ai.com/crp/module/camera_module.git}"
CAMERA_BRANCH="${CAMERA_BRANCH:-dev/0.x}"
CAMERA_EXTRA="${CAMERA_EXTRA:-zivid}"
PASS_CAMERA="${PASS_CAMERA:-gitlab/cmesrobotics/camera_module}"
PASS_CRP_CORE="${PASS_CRP_CORE:-gitlab/cmesrobotics/crp_core}"

MODE=install
SKIP_DEPS=0
DEPS_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --pull)      MODE=pull ;;
        --skip-deps) SKIP_DEPS=1 ;;
        --deps-only) DEPS_ONLY=1 ;;
        -h|--help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 2
            ;;
    esac
done

install_venv_host() {
    ensure_uv
    cd "$CAMERA_MODULE_DIR"
    create_or_refresh_venv
    IFS=$'\t' read -r crp_user crp_token < <(pass_token_user "$PASS_CRP_CORE")
    echo ">> uv pip install -e .[${CAMERA_EXTRA}] in $CAMERA_MODULE_DIR"
    pip_install_editable "$crp_user" "$crp_token"
    unset crp_user crp_token
}

main() {
    "$REPO_ROOT/common/setup-pass.sh" --check >/dev/null 2>&1 \
        || "$REPO_ROOT/common/setup-pass.sh"

    if (( DEPS_ONLY == 1 )); then
        install_host_deps
        echo ">> host deps OK"
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
            echo ">> Installed: $CAMERA_MODULE_DIR"
            echo ">> Activate:  source $CAMERA_MODULE_DIR/.venv/bin/activate"
            echo ">> Zivid test: ./host/run_zivid_capture.sh"
            ;;
    esac
}

main
