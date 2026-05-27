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
    [[ -n "$extra" ]] || {
        EXTRA_NAME=""
        CAPTURE_ENABLED="${CAPTURE_ENABLED:-0}"
        return 0
    }
    local profile="$REPO_ROOT/configs/extras/${extra}.env"
    [[ -f "$profile" ]] || {
        echo "ERROR: unknown extra '$extra' (configs/extras/${extra}.env)" >&2
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
            echo ">> Capture:   MODULE_EXTRA=${MODULE_EXTRA:-} ./docker/run_capture.sh $MODULE_NAME"
        else
            echo ">> Capture:   MODULE_EXTRA=${MODULE_EXTRA:-} ./host/run_capture.sh $MODULE_NAME"
        fi
    elif [[ -n "${MODULE_RUN_HINT:-}" ]]; then
        echo ">> Run:       $MODULE_RUN_HINT"
    fi
}
