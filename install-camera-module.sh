#!/usr/bin/env bash
#
# install-camera-module.sh — clone + venv at ~/camera_module (pass tokens, Docker for Zivid deps)
#
# Usage:
#   ./install-camera-module.sh
#   ./install-camera-module.sh --pull          git pull only
#   CAMERA_MODULE_DIR=~/src/camera_module ./install-camera-module.sh
#
# Env:
#   CAMERA_MODULE_DIR   default: $HOME/camera_module
#   CAMERA_REPO         default: gitlab.cmes-ai.com/crp/module/camera_module.git
#   CAMERA_BRANCH       default: dev/0.x
#   CAMERA_EXTRA        default: zivid
#   IMAGE               default: cmes/camera-module:dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CAMERA_MODULE_DIR="${CAMERA_MODULE_DIR:-$HOME/camera_module}"
CAMERA_REPO="${CAMERA_REPO:-gitlab.cmes-ai.com/crp/module/camera_module.git}"
CAMERA_BRANCH="${CAMERA_BRANCH:-dev/0.x}"
CAMERA_EXTRA="${CAMERA_EXTRA:-zivid}"
IMAGE="${IMAGE:-cmes/camera-module:dev}"
PASS_CAMERA="${PASS_CAMERA:-gitlab/cmesrobotics/camera_module}"
PASS_CRP_CORE="${PASS_CRP_CORE:-gitlab/cmesrobotics/crp_core}"

MODE=install
[[ "${1:-}" == "--pull" ]] && MODE=pull

pass_token_user() {
    local entry=$1
    local token user
    token="$(pass show "$entry" | sed -n '1p')"
    user="$(pass show "$entry" | sed -nE 's/^login:[[:space:]]*//p')"
    [[ -n "$token" && -n "$user" ]] || {
        echo "ERROR: pass '$entry' needs token + login: line" >&2
        exit 1
    }
    printf '%s\t%s' "$user" "$token"
}

ensure_image() {
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        return 0
    fi
    echo ">> image '$IMAGE' not found — run: make build" >&2
    exit 1
}

clone_or_pull() {
    mkdir -p "$(dirname "$CAMERA_MODULE_DIR")"
    if [[ -d "$CAMERA_MODULE_DIR/.git" ]]; then
        echo ">> git pull $CAMERA_MODULE_DIR"
        git -C "$CAMERA_MODULE_DIR" pull --ff-only
        return 0
    fi
    if [[ -d "$CAMERA_MODULE_DIR" ]]; then
        echo "ERROR: $CAMERA_MODULE_DIR exists but is not a git repo" >&2
        exit 1
    fi
    IFS=$'\t' read -r git_user git_token < <(pass_token_user "$PASS_CAMERA")
    echo ">> git clone → $CAMERA_MODULE_DIR"
    git clone --branch "$CAMERA_BRANCH" \
        "https://${git_user}:${git_token}@${CAMERA_REPO}" "$CAMERA_MODULE_DIR"
    git -C "$CAMERA_MODULE_DIR" remote set-url origin "https://${CAMERA_REPO}"
    unset git_user git_token
}

install_venv() {
    ensure_image
    IFS=$'\t' read -r crp_user crp_token < <(pass_token_user "$PASS_CRP_CORE")
    echo ">> uv venv + pip install -e .[${CAMERA_EXTRA}] in $CAMERA_MODULE_DIR"
    docker run --rm \
        -v "$CAMERA_MODULE_DIR:$CAMERA_MODULE_DIR" \
        -w "$CAMERA_MODULE_DIR" \
        -e "CRP_CORE_USER=${crp_user}" \
        -e "CRP_CORE_TOKEN=${crp_token}" \
        "$IMAGE" \
        bash -c '
            set -eu
            git config --global --add safe.directory '"$CAMERA_MODULE_DIR"' 2>/dev/null || true
            uv venv --python 3.10 .venv
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
    "$SCRIPT_DIR/setup-pass.sh" --check >/dev/null 2>&1 || "$SCRIPT_DIR/setup-pass.sh"
    case "$MODE" in
        pull)
            clone_or_pull
            ;;
        install)
            clone_or_pull
            install_venv
            echo
            echo ">> Installed: $CAMERA_MODULE_DIR"
            echo ">> Run: cd $SCRIPT_DIR && ./run_container.sh --gpu"
            ;;
    esac
}

main
