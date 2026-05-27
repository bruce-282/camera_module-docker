# capture-test.sh — run optional capture smoke test from extra profile

run_capture_test() {
    if [[ "${CAPTURE_ENABLED:-0}" != "1" ]]; then
        echo ">> No capture test for extra '${MODULE_EXTRA:-none}'" >&2
        return 0
    fi

    local script="${CAPTURE_SCRIPT:-$REPO_ROOT/common/capture/zivid_virtual.py}"
    [[ -f "$script" ]] || {
        echo "ERROR: capture script not found: $script" >&2
        exit 1
    }

    export MODULE_DIR
    export CAPTURE_WORKDIR CAPTURE_CAMERA_TYPE CAPTURE_DEVICE_ID
    export CAPTURE_VIRTUAL_DATA CAPTURE_CONFIG CAPTURE_PROJECT CAPTURE_NODE

    echo ">> capture test: module=$MODULE_NAME extra=${MODULE_EXTRA:-} device=${CAPTURE_DEVICE_ID}"
    python3 "$script"
}
