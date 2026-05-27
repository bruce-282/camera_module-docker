# examples/capture/lib.sh — optional smoke test (example only, not core install)

EXAMPLES_CAPTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

default_capture_script() {
    echo "${EXAMPLES_CAPTURE_DIR}/zivid_virtual.py"
}

run_capture_test() {
    if [[ "${CAPTURE_ENABLED:-0}" != "1" ]]; then
        echo ">> No capture example for extra '${MODULE_EXTRA:-none}'" >&2
        return 0
    fi

    local script="${CAPTURE_SCRIPT:-$(default_capture_script)}"
    [[ -f "$script" ]] || {
        echo "ERROR: capture example not found: $script" >&2
        exit 1
    }

    export MODULE_DIR
    export CAPTURE_WORKDIR CAPTURE_CAMERA_TYPE CAPTURE_DEVICE_ID
    export CAPTURE_VIRTUAL_DATA CAPTURE_CONFIG CAPTURE_PROJECT CAPTURE_NODE

    echo ">> capture example: module=$MODULE_NAME extra=${MODULE_EXTRA:-} device=${CAPTURE_DEVICE_ID}"
    python3 "$script"
}
