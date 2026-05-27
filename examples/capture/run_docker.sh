#!/usr/bin/env bash
# Example: capture smoke test via Docker (+ GPU when extra requires)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

MODULE="${MODULE:-camera_module}"
MODULE_EXTRA="${MODULE_EXTRA:-${CAMERA_EXTRA:-}}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --module)    MODULE="$2"; shift 2 ;;
        --module=*)  MODULE="${1#*=}"; shift ;;
        --extra)     MODULE_EXTRA="$2"; shift 2 ;;
        --extra=*)   MODULE_EXTRA="${1#*=}"; shift ;;
        -h|--help)
            echo "Usage: $(basename "$0") [module] [--extra zivid]"
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *)   MODULE="$1"; shift ;;
    esac
done

load_module_profile "$MODULE"
[[ -n "${MODULE_EXTRA:-}" ]] || MODULE_EXTRA="${MODULE_PIP_EXTRA_DEFAULT:-}"
load_extra_profile "${MODULE_EXTRA:-}"
apply_legacy_aliases

if [[ "${CAPTURE_ENABLED:-0}" != "1" ]]; then
    echo ">> No capture example for extra '${MODULE_EXTRA:-none}'" >&2
    exit 0
fi

GPU_ARGS=()
if [[ "${CAPTURE_GPU:-0}" == "1" ]]; then
    GPU_ARGS=(--gpu)
fi

CAPTURE_SCRIPT="${CAPTURE_SCRIPT:-$(default_capture_script)}"

exec "${REPO_ROOT}/docker/run_container.sh" "${GPU_ARGS[@]}" --module "$MODULE" bash -c "
set -eu
cd '${MODULE_DIR}/${CAPTURE_WORKDIR}'
export MODULE_DIR='${MODULE_DIR}'
export CAPTURE_WORKDIR='${CAPTURE_WORKDIR}'
export CAPTURE_CAMERA_TYPE='${CAPTURE_CAMERA_TYPE}'
export CAPTURE_DEVICE_ID='${CAPTURE_DEVICE_ID}'
export CAPTURE_VIRTUAL_DATA='${CAPTURE_VIRTUAL_DATA}'
export CAPTURE_CONFIG='${CAPTURE_CONFIG}'
export CAPTURE_PROJECT='${CAPTURE_PROJECT}'
export CAPTURE_NODE='${CAPTURE_NODE}'
python3 '${CAPTURE_SCRIPT}'
"
