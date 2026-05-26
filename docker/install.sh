#!/usr/bin/env bash
#
# docker/install.sh — clone + venv at ~/camera_module (pass + Docker for Zivid deps)
#
# Usage:
#   ./docker/install.sh
#   ./docker/install.sh --pull
#   make install
#
# Host-only: ../host/install.sh  or  make install-host

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/install-common.sh
source "$REPO_ROOT/common/install-common.sh"

CAMERA_MODULE_DIR="${CAMERA_MODULE_DIR:-$HOME/camera_module}"
CAMERA_REPO="${CAMERA_REPO:-gitlab.cmes-ai.com/crp/module/camera_module.git}"
CAMERA_BRANCH="${CAMERA_BRANCH:-dev/0.x}"
CAMERA_EXTRA="${CAMERA_EXTRA:-zivid}"
IMAGE="${IMAGE:-cmes/camera-module:dev}"
PASS_CAMERA="${PASS_CAMERA:-gitlab/cmesrobotics/camera_module}"
PASS_CRP_CORE="${PASS_CRP_CORE:-gitlab/cmesrobotics/crp_core}"

MODE=install
[[ "${1:-}" == "--pull" ]] && MODE=pull

ensure_image() {
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        return 0
    fi
    echo ">> image '$IMAGE' not found — run: make build" >&2
    exit 1
}

cleanup_root_owned() {
    if ! find "$CAMERA_MODULE_DIR" -user root -print -quit 2>/dev/null | grep -q .; then
        return 0
    fi
    echo ">> fixing root-owned files in $CAMERA_MODULE_DIR (previous install without --user)"
    docker run --rm \
        -v "$CAMERA_MODULE_DIR:$CAMERA_MODULE_DIR" \
        "$IMAGE" \
        chown -R "$(id -u):$(id -g)" "$CAMERA_MODULE_DIR"
}

install_venv() {
    ensure_image
    cleanup_root_owned
    if [[ -d "$CAMERA_MODULE_DIR/.venv" ]]; then
        if [[ ! -w "$CAMERA_MODULE_DIR/.venv" ]] \
            || [[ ! -x "$CAMERA_MODULE_DIR/.venv/bin/python" ]]; then
            echo ">> removing broken .venv (wrong owner or incomplete)"
            docker run --rm \
                -v "$CAMERA_MODULE_DIR:$CAMERA_MODULE_DIR" \
                "$IMAGE" \
                rm -rf "$CAMERA_MODULE_DIR/.venv"
        fi
    fi
    IFS=$'\t' read -r crp_user crp_token < <(pass_token_user "$PASS_CRP_CORE")
    echo ">> uv venv + pip install -e .[${CAMERA_EXTRA}] in $CAMERA_MODULE_DIR"
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$CAMERA_MODULE_DIR:$CAMERA_MODULE_DIR" \
        -w "$CAMERA_MODULE_DIR" \
        -e "HOME=${CAMERA_MODULE_DIR}/.docker-home" \
        -e "UV_CACHE_DIR=${CAMERA_MODULE_DIR}/.cache/uv" \
        -e "UV_LINK_MODE=copy" \
        -e "CRP_CORE_USER=${crp_user}" \
        -e "CRP_CORE_TOKEN=${crp_token}" \
        "$IMAGE" \
        bash -c '
            set -eu
            mkdir -p "$HOME"
            git config --global --add safe.directory '"$CAMERA_MODULE_DIR"' 2>/dev/null || true
            if [[ -d .venv ]]; then
                echo ">> replacing existing .venv"
                uv venv --python 3.10 --clear .venv
            else
                uv venv --python 3.10 .venv
            fi
            export VIRTUAL_ENV='"$CAMERA_MODULE_DIR"'/.venv
            export PATH="$VIRTUAL_ENV/bin:$PATH"
            git config --global credential.https://gitlab.cmes-ai.com.helper \
                "!f() { echo username=${CRP_CORE_USER}; echo password=${CRP_CORE_TOKEN}; }; f"
            uv pip install -e ".['"${CAMERA_EXTRA}"']"
            git config --global --unset credential.https://gitlab.cmes-ai.com.helper || true
            ! grep -RIE "https://[^/[:space:]]*:[^@[:space:]/]+@gitlab" .venv 2>/dev/null \
                || (echo "ERROR: token URL in venv" && exit 1)
            python -c "import crp_camera, crp_core; print(\"OK:\", crp_camera.__file__)"
        '
    unset crp_user crp_token
}

main() {
    "$REPO_ROOT/common/setup-pass.sh" --check >/dev/null 2>&1 \
        || "$REPO_ROOT/common/setup-pass.sh"
    case "$MODE" in
        pull)
            clone_or_pull
            ;;
        install)
            clone_or_pull
            install_venv
            echo
            echo ">> Installed: $CAMERA_MODULE_DIR"
            echo ">> Run: make shell   or   ./docker/run_container.sh --gpu"
            ;;
    esac
}

main
