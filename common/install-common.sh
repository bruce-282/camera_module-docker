# install-common.sh — shared clone + pip helpers (source from install scripts)

pass_token_user() {
    local entry=$1
    local token user
    token="$(pass show "$entry" | sed -n '1p')"
    user="$(pass show "$entry" | sed -nE 's/^login:[[:space:]]*//p')"
    [[ -n "$token" && -n "$user" ]] || {
        echo "ERROR: pass '$entry' needs token + login: line" >&2
        exit 1
    }
    printf '%s\t%s\n' "$user" "$token"
}

clone_or_pull() {
    mkdir -p "$(dirname "$CAMERA_MODULE_DIR")"
    if [[ -d "$CAMERA_MODULE_DIR/.git" ]]; then
        echo ">> git pull $CAMERA_MODULE_DIR"
        git -C "$CAMERA_MODULE_DIR" pull --ff-only
        return 0
    fi
    if [[ -d "$CAMERA_MODULE_DIR" ]]; then
        echo "ERROR: $CAMERA_MODULE_DIR exists but is not a git repo" >&2
        exit 1
    fi
    IFS=$'\t' read -r git_user git_token < <(pass_token_user "$PASS_CAMERA")
    echo ">> git clone → $CAMERA_MODULE_DIR"
    git clone --branch "$CAMERA_BRANCH" \
        "https://${git_user}:${git_token}@${CAMERA_REPO}" "$CAMERA_MODULE_DIR"
    git -C "$CAMERA_MODULE_DIR" remote set-url origin "https://${CAMERA_REPO}"
    unset git_user git_token
}

verify_venv_no_token_leak() {
    ! grep -RIE "https://[^/[:space:]]*:[^@[:space:]/]+@gitlab" "$CAMERA_MODULE_DIR/.venv" 2>/dev/null \
        || { echo "ERROR: token URL in venv" >&2; exit 1; }
}

pip_install_editable() {
    local crp_user=$1 crp_token=$2
    local import_check="import crp_camera, crp_core"
    if [[ "$CAMERA_EXTRA" == "zivid" ]]; then
        import_check="${import_check}, zivid"
    fi

    git config --global --add safe.directory "$CAMERA_MODULE_DIR" 2>/dev/null || true
    git config --global credential.https://gitlab.cmes-ai.com.helper \
        "!f() { echo username=${crp_user}; echo password=${crp_token}; }; f"
    uv pip install -e ".[${CAMERA_EXTRA}]"
    git config --global --unset credential.https://gitlab.cmes-ai.com.helper || true
    verify_venv_no_token_leak
    python -c "${import_check}; print('OK:', crp_camera.__file__)"
}

create_or_refresh_venv() {
    if [[ -d .venv ]]; then
        echo ">> replacing existing .venv"
        uv venv --python 3.10 --clear .venv
    else
        uv venv --python 3.10 .venv
    fi
    export VIRTUAL_ENV="${CAMERA_MODULE_DIR}/.venv"
    export PATH="${VIRTUAL_ENV}/bin:${PATH}"
}
