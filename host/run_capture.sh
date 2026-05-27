#!/usr/bin/env bash
# host/run_capture.sh — optional capture smoke test (extra profile driven)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../common/module-config.sh
source "$REPO_ROOT/common/module-config.sh"
# shellcheck source=../common/capture-test.sh
source "$REPO_ROOT/common/capture-test.sh"

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

VENV="${MODULE_DIR}/.venv"
if [[ ! -x "${VENV}/bin/python" ]]; then
    echo "ERROR: ${VENV} not ready — run: make install-host MODULE=$MODULE" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "${VENV}/bin/activate"
run_capture_test
