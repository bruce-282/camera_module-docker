#!/usr/bin/env bash
#
# docker/run_container.sh — launch module container
#
# Usage:
#   ./docker/run_container.sh --gpu [--module camera_module]
#   make shell

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"

MODULE="${MODULE:-camera_module}"
MODULE_EXTRA="${MODULE_EXTRA:-${CAMERA_EXTRA:-}}"
IMAGE="${IMAGE:-}"
MODULE_DIR="${MODULE_DIR:-${CAMERA_MODULE_DIR:-}}"
USB="${USB:-1}"
X11="${X11:-0}"
MOUNT_WS="${MOUNT_WS:-}"
GPU="${GPU:-0}"
SMOKE_TEST=0
NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-usb)      USB=0; shift ;;
        --x11)         X11=1; shift ;;
        --mount-ws)    MOUNT_WS="$2"; shift 2 ;;
        --gpu)         GPU=1; shift ;;
        --smoke-test)  SMOKE_TEST=1; shift ;;
        --image)       IMAGE="$2"; shift 2 ;;
        --name)        NAME="$2"; shift 2 ;;
        --module)      MODULE="$2"; shift 2 ;;
        --module=*)    MODULE="${1#*=}"; shift ;;
        --extra)       MODULE_EXTRA="$2"; shift 2 ;;
        --extra=*)     MODULE_EXTRA="${1#*=}"; shift ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--gpu] [--module NAME] [cmd...]"
            exit 0
            ;;
        --) shift; break ;;
        -*)
            echo "unknown flag: $1" >&2
            exit 2
            ;;
        *) break ;;
    esac
done

if [[ -z "$MODULE_DIR" || -z "$IMAGE" ]]; then
    load_module_profile "$MODULE"
    [[ -n "${MODULE_EXTRA:-}" ]] || MODULE_EXTRA="${MODULE_PIP_EXTRA_DEFAULT:-}"
    [[ -n "${MODULE_EXTRA:-}" ]] && load_extra_profile "$MODULE_EXTRA"
    apply_legacy_aliases
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found" >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: image '$IMAGE' not found — run: make build MODULE=$MODULE" >&2
    exit 1
fi

if [[ ! -f "$MODULE_DIR/.venv/pyvenv.cfg" ]]; then
    echo "ERROR: $MODULE_DIR/.venv not ready — run: make install MODULE=$MODULE" >&2
    exit 1
fi

MODULE_DIR="$(cd "$MODULE_DIR" && pwd)"
CMES_DIR="${CMES_DIR:-$HOME/.cmes}"
mkdir -p "$HOME/.cache"

DOCKER_ARGS=(
    --rm
    --user "$(id -u):$(id -g)"
    -w "$MODULE_DIR"
    -v "$MODULE_DIR:$MODULE_DIR"
    -v "$CMES_DIR:$CMES_DIR"
    -v "$HOME/.cache:$HOME/.cache"
    -e "HOME=${HOME}"
    -e "MODULE_DIR=${MODULE_DIR}"
    -e "CAMERA_MODULE_DIR=${MODULE_DIR}"
    -e "VIRTUAL_ENV=${MODULE_DIR}/.venv"
    -e "PATH=${MODULE_DIR}/.venv/bin:/usr/local/bin:/usr/bin:/bin"
)
if [[ -f /etc/passwd && -f /etc/group ]]; then
    DOCKER_ARGS+=(-v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro)
fi
if [[ -t 0 && -t 1 ]]; then
    DOCKER_ARGS+=(-it)
else
    DOCKER_ARGS+=(-i)
fi

[[ -n "$NAME" ]] && DOCKER_ARGS+=(--name "$NAME")

if [[ "$USB" == "1" && -d /dev/bus/usb ]]; then
    DOCKER_ARGS+=(
        --device-cgroup-rule='c 189:* rmw'
        -v /dev/bus/usb:/dev/bus/usb
    )
elif [[ "$USB" == "1" ]]; then
    echo "WARN: /dev/bus/usb missing; skipping USB" >&2
fi

if [[ "$X11" == "1" ]]; then
    command -v xhost >/dev/null 2>&1 && xhost +local:docker >/dev/null 2>&1 || true
    DOCKER_ARGS+=(
        -e "DISPLAY=${DISPLAY:-:0}"
        -v /tmp/.X11-unix:/tmp/.X11-unix:ro
    )
    [[ -n "${XAUTHORITY:-}" && -f "$XAUTHORITY" ]] && DOCKER_ARGS+=(
        -v "${XAUTHORITY}:${XAUTHORITY}:ro"
        -e XAUTHORITY="$XAUTHORITY"
    )
fi

if [[ -n "$MOUNT_WS" ]]; then
    [[ -d "$MOUNT_WS" ]] || { echo "ERROR: --mount-ws '$MOUNT_WS' not found" >&2; exit 1; }
    DOCKER_ARGS+=(-v "$(cd "$MOUNT_WS" && pwd):/workspace")
fi

if [[ "$GPU" == "1" ]]; then
    DOCKER_ARGS+=(--gpus all)
    if [[ -d /etc/OpenCL/vendors ]]; then
        DOCKER_ARGS+=(-v /etc/OpenCL/vendors:/etc/OpenCL/vendors:ro)
    else
        echo "WARN: /etc/OpenCL/vendors missing on host; Zivid OpenCL may fail" >&2
    fi
fi

if [[ $# -gt 0 ]]; then
    CONTAINER_CMD=("$@")
elif [[ "$SMOKE_TEST" == "1" ]]; then
    CONTAINER_CMD=(python3 -c "import crp_camera, crp_core; print('OK')")
else
    CONTAINER_CMD=(bash)
fi

echo ">> image: $IMAGE"
echo ">> module: $MODULE  workspace: $MODULE_DIR"
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" "${CONTAINER_CMD[@]}"
