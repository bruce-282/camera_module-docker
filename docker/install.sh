#!/usr/bin/env bash
#
# docker/install.sh — clone + venv (pass + Docker runtime)
#
# Usage:
#   ./docker/install.sh [module] [--extra zivid]
#   make install MODULE=camera_module MODULE_EXTRA=zivid

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"
# shellcheck source=../common/install-common.sh
source "$REPO_ROOT/common/install-common.sh"

MODULE="${MODULE:-camera_module}"
MODULE_EXTRA="${MODULE_EXTRA:-${CAMERA_EXTRA:-}}"
MODE=install

usage() {
    cat <<EOF
Usage: $(basename "$0") [module] [options]

  --extra NAME   pip extra (zivid, orbbec-linux, none, ...)
  --pull         git pull only
  --list         list module profiles
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pull)      MODE=pull; shift ;;
        --list)      list_modules; exit 0 ;;
        --module)    MODULE="$2"; shift 2 ;;
        --module=*)  MODULE="${1#*=}"; shift ;;
        --extra)     MODULE_EXTRA="$2"; shift 2 ;;
        --extra=*)   MODULE_EXTRA="${1#*=}"; shift ;;
        -h|--help)   usage; exit 0 ;;
        --*)         echo "Unknown option: $1" >&2; exit 2 ;;
        *)           MODULE="$1"; shift ;;
    esac
done

load_module_profile "$MODULE"
[[ -n "${MODULE_EXTRA:-}" ]] || MODULE_EXTRA="${MODULE_PIP_EXTRA_DEFAULT:-}"
load_extra_profile "${MODULE_EXTRA:-}"
apply_legacy_aliases

ensure_image() {
    if docker image inspect "$IMAGE" >/dev/null 2>&1; then
        return 0
    fi
    echo ">> image '$IMAGE' not found — run: make build MODULE=$MODULE MODULE_EXTRA=${MODULE_EXTRA:-}" >&2
    exit 1
}

cleanup_root_owned() {
    if ! find "$MODULE_DIR" -user root -print -quit 2>/dev/null | grep -q .; then
        return 0
    fi
    echo ">> fixing root-owned files in $MODULE_DIR"
    docker run --rm -v "$MODULE_DIR:$MODULE_DIR" "$IMAGE" \
        chown -R "$(id -u):$(id -g)" "$MODULE_DIR"
}

install_venv() {
    ensure_image
    cleanup_root_owned
    if [[ -d "$MODULE_DIR/.venv" ]]; then
        if [[ ! -w "$MODULE_DIR/.venv" ]] \
            || [[ ! -x "$MODULE_DIR/.venv/bin/python" ]]; then
            echo ">> removing broken .venv"
            docker run --rm -v "$MODULE_DIR:$MODULE_DIR" "$IMAGE" \
                rm -rf "$MODULE_DIR/.venv"
        fi
    fi
    IFS=$'\t' read -r pip_user pip_token < <(pass_token_user "$PASS_PIP")
    local spec="."
    [[ -n "${MODULE_EXTRA:-}" && "${MODULE_EXTRA}" != "none" ]] && spec=".[${MODULE_EXTRA}]"
    local verify_py="" pkg first="${VERIFY_IMPORTS%% *}"
    [[ -n "$first" ]] || first="${VERIFY_IMPORTS_EXTRA%% *}"
    for pkg in ${VERIFY_IMPORTS:-} ${VERIFY_IMPORTS_EXTRA:-}; do
        [[ -n "$pkg" ]] || continue
        verify_py="${verify_py}import ${pkg}; "
    done
    [[ -n "$verify_py" ]] && verify_py="${verify_py}print('OK:', ${first}.__file__)"
    echo ">> uv pip install in $MODULE_DIR (extra=${MODULE_EXTRA:-none})"
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$MODULE_DIR:$MODULE_DIR" \
        -w "$MODULE_DIR" \
        -e "HOME=${MODULE_DIR}/.docker-home" \
        -e "UV_CACHE_DIR=${MODULE_DIR}/.cache/uv" \
        -e "UV_LINK_MODE=copy" \
        -e "PIP_USER=${pip_user}" \
        -e "PIP_TOKEN=${pip_token}" \
        -e "INSTALL_SPEC=${spec}" \
        -e "VERIFY_PY=${verify_py}" \
        "$IMAGE" \
        bash -c '
            set -eu
            mkdir -p "$HOME"
            git config --global --add safe.directory '"$MODULE_DIR"' 2>/dev/null || true
            if [[ -d .venv ]]; then uv venv --python 3.10 --clear .venv
            else uv venv --python 3.10 .venv; fi
            export VIRTUAL_ENV='"$MODULE_DIR"'/.venv PATH="$VIRTUAL_ENV/bin:$PATH"
            git config --global credential.https://gitlab.cmes-ai.com.helper \
                "!f() { echo username=${PIP_USER}; echo password=${PIP_TOKEN}; }; f"
            uv pip install -e "${INSTALL_SPEC}"
            git config --global --unset credential.https://gitlab.cmes-ai.com.helper || true
            ! grep -RIE "https://[^/[:space:]]*:[^@[:space:]/]+@gitlab" .venv 2>/dev/null \
                || (echo "ERROR: token URL in venv" && exit 1)
            [[ -n "${VERIFY_PY}" ]] && python -c "${VERIFY_PY}"
        '
    unset pip_user pip_token
}

main() {
    "$REPO_ROOT/common/setup-pass.sh" --check >/dev/null 2>&1 \
        || "$REPO_ROOT/common/setup-pass.sh"
    case "$MODE" in
        pull)  clone_or_pull ;;
        install)
            clone_or_pull
            install_venv
            echo
            print_install_summary docker
            ;;
    esac
}

main "$@"
