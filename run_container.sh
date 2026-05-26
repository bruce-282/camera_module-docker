#!/usr/bin/env bash
#
# run_container.sh — launch camera_module container
#
# Code + venv: ~/camera_module on host (make install), same path inside container.
# Zivid: use --gpu (see README).
#
# Usage:
#   ./run_container.sh                    # bash @ ~/camera_module
#   ./run_container.sh --gpu bash
#   ./run_container.sh python3 scripts/python_run/capture_zivid_camera.py ...
#
# Env:
#   CAMERA_MODULE_DIR   default: $HOME/camera_module

set -euo pipefail

IMAGE="${IMAGE:-cmes/camera-module:dev}"
CAMERA_MODULE_DIR="${CAMERA_MODULE_DIR:-$HOME/camera_module}"
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
        -h|--help)
            sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
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

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found" >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "ERROR: image '$IMAGE' not found — run: make build" >&2
    exit 1
fi

if [[ ! -d "$CAMERA_MODULE_DIR/.venv" ]]; then
    echo "ERROR: $CAMERA_MODULE_DIR/.venv not found — run: make install" >&2
    exit 1
fi

CAMERA_MODULE_DIR="$(cd "$CAMERA_MODULE_DIR" && pwd)"
CMES_DIR="${CMES_DIR:-$HOME/.cmes}"

DOCKER_ARGS=(
    --rm -it
    --user "$(id -u):$(id -g)"
    -w "$CAMERA_MODULE_DIR"
    -v "$CAMERA_MODULE_DIR:$CAMERA_MODULE_DIR"
    -v "$CMES_DIR:$CMES_DIR"
    -e "HOME=${HOME}"
    -e "VIRTUAL_ENV=${CAMERA_MODULE_DIR}/.venv"
    -e "PATH=${CAMERA_MODULE_DIR}/.venv/bin:/usr/local/bin:/usr/bin:/bin"
)

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
echo ">> workspace: $CAMERA_MODULE_DIR"
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" "${CONTAINER_CMD[@]}"
