# module-config.sh — load module + extra profiles (source from install/run scripts)

list_modules() {
    local f name
    for f in "$REPO_ROOT"/configs/modules/*.env; do
        [[ -f "$f" ]] || continue
        name="$(basename "$f" .env)"
        [[ "$name" == _* ]] && continue
        echo "$name"
    done
}

list_module_extras() {
    local module=$1
    local dir="$REPO_ROOT/configs/modules/${module}/extras"
    local f
    [[ -d "$dir" ]] || return 0
    for f in "$dir"/*.env; do
        [[ -f "$f" ]] || continue
        basename "$f" .env
    done
}

module_has_extras() {
    [[ -d "$REPO_ROOT/configs/modules/${1}/extras" ]]
}

load_module_profile() {
    local name=$1
    local profile="$REPO_ROOT/configs/modules/${name}.env"
    [[ -f "$profile" ]] || {
        echo "ERROR: unknown module '$name' (configs/modules/${name}.env)" >&2
        echo "Available: $(list_modules | tr '\n' ' ')" >&2
        exit 1
    }
    # shellcheck disable=SC1090
    source "$profile"
    MODULE_NAME="${MODULE_NAME:-$name}"
    MODULE_DIR="${MODULE_DIR:-${MODULE_DIR_DEFAULT}}"
    MODULE_DIR="${MODULE_DIR/#\~/$HOME}"
    MODULE_EXTRA="${MODULE_EXTRA:-${MODULE_PIP_EXTRA_DEFAULT:-}}"
    IMAGE="${IMAGE:-${DOCKER_IMAGE:-cmes/${MODULE_NAME}:dev}}"
    apply_legacy_aliases
}

load_extra_profile() {
    local extra=$1
    if [[ -z "$extra" ]]; then
        EXTRA_NAME=""
        CAPTURE_ENABLED="${CAPTURE_ENABLED:-0}"
        HOST_INSTALL_ZIVID_SDK="${HOST_INSTALL_ZIVID_SDK:-0}"
        DOCKER_BUILD_ZIVID="${DOCKER_BUILD_ZIVID:-0}"
        VERIFY_IMPORTS_EXTRA="${VERIFY_IMPORTS_EXTRA:-}"
        return 0
    fi

    if ! module_has_extras "$MODULE_NAME"; then
        echo "ERROR: module '$MODULE_NAME' has no pip extras (no --extra)" >&2
        exit 1
    fi

    local profile="$REPO_ROOT/configs/modules/${MODULE_NAME}/extras/${extra}.env"
    [[ -f "$profile" ]] || {
        echo "ERROR: unknown extra '$extra' for module '$MODULE_NAME'" >&2
        echo "       expected: configs/modules/${MODULE_NAME}/extras/${extra}.env" >&2
        echo "Available: $(list_module_extras "$MODULE_NAME" | tr '\n' ' ')" >&2
        exit 1
    }
    # shellcheck disable=SC1090
    source "$profile"
    EXTRA_NAME="${EXTRA_NAME:-$extra}"
}

apply_legacy_aliases() {
    export CAMERA_MODULE_DIR="$MODULE_DIR"
    export CAMERA_REPO="$MODULE_REPO"
    export CAMERA_BRANCH="$MODULE_BRANCH"
    export CAMERA_EXTRA="$MODULE_EXTRA"
    export PASS_CAMERA="${PASS_CLONE}"
    export PASS_CRP_CORE="${PASS_PIP}"
}

# All PASS_CLONE / PASS_PIP entries from configs/modules/*.env (unique)
module_pass_entries() {
    local f name
    for f in "$REPO_ROOT"/configs/modules/*.env; do
        [[ -f "$f" ]] || continue
        name="$(basename "$f" .env)"
        [[ "$name" == _* ]] && continue
        # shellcheck disable=SC1090
        source "$f"
        printf '%s\n' "$PASS_CLONE" "$PASS_PIP"
    done
}

collect_pass_entries() {
    {
        echo "${PASS_CAMERA:-gitlab/cmesrobotics/camera_module}"
        echo "${PASS_CRP_CORE:-gitlab/cmesrobotics/crp_core}"
        module_pass_entries
    } | awk 'NF && !seen[$0]++'
}

init_module_config() {
    local default_module=${1:-camera_module}
    MODULE="${MODULE:-$default_module}"
    REPO_ROOT="${REPO_ROOT:?REPO_ROOT required}"

    local positional=""
    while [[ $# -gt 1 ]]; do
        case "$2" in
            --module)
                MODULE="$3"
                shift 2
                ;;
            --module=*)
                MODULE="${2#*=}"
                shift
                ;;
            --extra)
                MODULE_EXTRA="$3"
                shift 2
                ;;
            --extra=*)
                MODULE_EXTRA="${2#*=}"
                shift
                ;;
            --help|-h)
                return 2
                ;;
            --*)
                shift
                ;;
            *)
                positional="$2"
                shift
                ;;
        esac
    done

    [[ -n "$positional" ]] && MODULE="$positional"
    load_module_profile "$MODULE"
    load_extra_profile "${MODULE_EXTRA:-}"
}

print_install_summary() {
    local runtime=$1
    echo ">> Installed: $MODULE_DIR"
    echo ">> Module:    $MODULE_NAME  extra: ${MODULE_EXTRA:-none}"
    echo ">> Activate:  source $MODULE_DIR/.venv/bin/activate"
    if [[ "${CAPTURE_ENABLED:-0}" == "1" ]]; then
        if [[ "$runtime" == docker ]]; then
            echo ">> Example:   make capture   # examples/capture/run_docker.sh"
        else
            echo ">> Example:   make capture-host   # examples/capture/run_host.sh"
        fi
    elif [[ -n "${MODULE_RUN_HINT:-}" ]]; then
        echo ">> Run:       $MODULE_RUN_HINT"
    fi
}
