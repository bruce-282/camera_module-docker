#!/usr/bin/env bash
#
# run_container.sh — launch the camera_module container
#
# Ubuntu host + Docker CE. Code at /build/camera_module (from make build).
# Zivid: use --gpu and host OpenCL drivers (see README).
#
# Usage:
#   ./run_container.sh                    # bash in /build/camera_module
#   ./run_container.sh python3 script.py
#   ./run_container.sh --smoke-test
#
# Flags:
#   --no-usb       disable USB passthrough
#   --x11          X11 forwarding
#   --mount-ws DIR mount host dir at /workspace (data only, optional)
#   --gpu          --gpus all
#   --smoke-test   run image default CMD
#   --image IMG    image tag (default: cmes/camera-module:dev)
#   --name NAME    container name

set -euo pipefail

IMAGE="${IMAGE:-cmes/camera-module:dev}"
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
            sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
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

DOCKER_ARGS=(--rm -it -w /build/camera_module)

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
        -v "${XAUTHORITY}:/tmp/.Xauthority:ro"
        -e XAUTHORITY=/tmp/.Xauthority
    )
fi

if [[ -n "$MOUNT_WS" ]]; then
    [[ -d "$MOUNT_WS" ]] || { echo "ERROR: --mount-ws '$MOUNT_WS' not found" >&2; exit 1; }
    DOCKER_ARGS+=(-v "$(cd "$MOUNT_WS" && pwd):/workspace")
fi

if [[ "$GPU" == "1" ]]; then
    DOCKER_ARGS+=(--gpus all)
    # NVIDIA injects libnvidia-opencl.so; Zivid also needs ICD loader + vendor file from host.
    if [[ -d /etc/OpenCL/vendors ]]; then
        DOCKER_ARGS+=(-v /etc/OpenCL/vendors:/etc/OpenCL/vendors:ro)
    else
        echo "WARN: /etc/OpenCL/vendors missing on host; Zivid OpenCL may fail" >&2
    fi
fi

if [[ $# -gt 0 ]]; then
    CONTAINER_CMD=("$@")
elif [[ "$SMOKE_TEST" == "1" ]]; then
    CONTAINER_CMD=()
else
    CONTAINER_CMD=(bash)
fi

echo ">> image: $IMAGE  workspace: /build/camera_module"
exec docker run "${DOCKER_ARGS[@]}" "$IMAGE" "${CONTAINER_CMD[@]}"
