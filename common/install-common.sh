# install-common.sh — shared clone + pip helpers

pass_token_user() {
    local entry=$1
    local token user
    token="$(pass show "$entry" | sed -n '1p')"
    user="$(pass show "$entry" | sed -nE 's/^login:[[:space:]]*//p')"
    [[ -z "$user" ]] && user="oauth2"
    [[ -n "$token" ]] || {
        echo "ERROR: pass '$entry' needs a token on line 1" >&2
        exit 1
    }
    printf '%s\t%s\n' "$user" "$token"
}

clone_or_pull() {
    mkdir -p "$(dirname "$MODULE_DIR")"
    if [[ -d "$MODULE_DIR/.git" ]]; then
        echo ">> git pull $MODULE_DIR"
        git -C "$MODULE_DIR" pull --ff-only
        return 0
    fi
    if [[ -d "$MODULE_DIR" ]]; then
        echo "ERROR: $MODULE_DIR exists but is not a git repo" >&2
        exit 1
    fi
    IFS=$'\t' read -r git_user git_token < <(pass_token_user "$PASS_CLONE")
    echo ">> git clone → $MODULE_DIR ($MODULE_REPO @ $MODULE_BRANCH)"
    git clone --branch "$MODULE_BRANCH" \
        "https://${git_user}:${git_token}@${MODULE_REPO}" "$MODULE_DIR"
    git -C "$MODULE_DIR" remote set-url origin "https://${MODULE_REPO}"
    unset git_user git_token
}

verify_venv_no_token_leak() {
    ! grep -RIE "https://[^/[:space:]]*:[^@[:space:]/]+@gitlab" "$MODULE_DIR/.venv" 2>/dev/null \
        || { echo "ERROR: token URL in venv" >&2; exit 1; }
}

verify_imports() {
    local pkg py="" first
    for pkg in ${VERIFY_IMPORTS:-} ${VERIFY_IMPORTS_EXTRA:-}; do
        [[ -n "$pkg" ]] || continue
        py="${py}import ${pkg}; "
    done
    [[ -n "$py" ]] || return 0
    first="${VERIFY_IMPORTS%% *}"
    [[ -n "$first" ]] || first="${VERIFY_IMPORTS_EXTRA%% *}"
    python -c "${py}print('OK:', ${first}.__file__)"
}

pip_install_editable() {
    local pip_user=$1 pip_token=$2
    local spec="."

    git config --global --add safe.directory "$MODULE_DIR" 2>/dev/null || true
    git config --global credential.https://gitlab.cmes-ai.com.helper \
        "!f() { echo username=${pip_user}; echo password=${pip_token}; }; f"
    if [[ -n "${MODULE_EXTRA:-}" && "${MODULE_EXTRA}" != "none" ]]; then
        spec=".[${MODULE_EXTRA}]"
    fi
    uv pip install -e "$spec"
    git config --global --unset credential.https://gitlab.cmes-ai.com.helper || true
    verify_venv_no_token_leak
    verify_imports
}

create_or_refresh_venv() {
    if [[ -d .venv ]]; then
        echo ">> replacing existing .venv"
        uv venv --python 3.10 --clear .venv
    else
        uv venv --python 3.10 .venv
    fi
    export VIRTUAL_ENV="${MODULE_DIR}/.venv"
    export PATH="${VIRTUAL_ENV}/bin:${PATH}"
}
