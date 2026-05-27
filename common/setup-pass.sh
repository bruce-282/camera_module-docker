#!/usr/bin/env bash
#
# setup-pass.sh — install pass and sync team password-store from GitLab
#
# Usage:
#   ./setup-pass.sh              install deps, clone/pull store, verify entries
#   ./setup-pass.sh --check      verify entries only (same rules as make check-pass)
#   ./setup-pass.sh --install    apt install pass + gnupg + git only
#   ./setup-pass.sh --pull       git pull in existing password-store
#   ./setup-pass.sh --local      create empty local store (NOT for CMES team store)
#
# Env:
#   PASS_STORE_REPO   default: https://gitlab.cmes-ai.com/bruce/password-store.git
#   PASS_STORE_DIR    default: ~/.password-store
#   PASS_CAMERA       default: gitlab/cmesrobotics/camera_module
#   PASS_CRP_CORE     default: gitlab/cmesrobotics/crp_core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=module-config.sh
source "$SCRIPT_DIR/module-config.sh"

PASS_CAMERA="${PASS_CAMERA:-gitlab/cmesrobotics/camera_module}"
PASS_CRP_CORE="${PASS_CRP_CORE:-gitlab/cmesrobotics/crp_core}"
PASS_STORE_REPO="${PASS_STORE_REPO:-https://gitlab.cmes-ai.com/bruce/password-store.git}"
PASS_STORE_DIR="${PASS_STORE_DIR:-${PASSWORD_STORE:-$HOME/.password-store}}"

MODE=setup
for arg in "$@"; do
    case "$arg" in
        --check|--check-only)     MODE=check ;;
        --install|--install-only) MODE=install ;;
        --pull)                   MODE=pull ;;
        --local)                  MODE=local ;;
        -h|--help)
            sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (try --help)" >&2
            exit 2
            ;;
    esac
done

install_pass_packages() {
    local need=0
    command -v pass >/dev/null 2>&1 || need=1
    command -v gpg >/dev/null 2>&1 || need=1
    command -v git >/dev/null 2>&1 || need=1
    if (( need == 0 )); then
        echo ">> pass, gpg, git already installed"
        return 0
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "ERROR: apt-get not found. Install pass, gnupg, git manually." >&2
        exit 1
    fi
    echo ">> installing pass, gnupg, git (sudo)..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y pass gnupg git
}

gpg_secret_key_ids() {
    gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
        | awk -F/ '/^sec/ { print $2 }' | awk '{ print $1 }'
}

gpg_can_decrypt_store() {
    local id
    [[ -f "${PASS_STORE_DIR}/.gpg-id" ]] || return 1
    while IFS= read -r id; do
        id="${id%%$'\r'}"
        [[ -z "${id// }" ]] && continue
        gpg --list-secret-keys "${id}" >/dev/null 2>&1 && return 0
    done < "${PASS_STORE_DIR}/.gpg-id"
    return 1
}

require_gpg_for_store() {
    if [[ ! -f "${PASS_STORE_DIR}/.gpg-id" ]]; then
        require_any_gpg_key
        return 0
    fi

    if gpg_can_decrypt_store; then
        echo ">> GPG key matches password-store .gpg-id"
        return 0
    fi

    echo ">> password-store .gpg-id:" >&2
    sed 's/^/     /' "${PASS_STORE_DIR}/.gpg-id" >&2
    echo ">> your secret keys:" >&2
    gpg --list-secret-keys 2>/dev/null | sed 's/^/     /' >&2 || true
    cat >&2 <<'EOF'
ERROR: your GPG key cannot decrypt the team password-store.

Import the private key listed in .gpg-id (backup / admin), then:

  gpg --import /path/to/private-key.asc
  ./setup-pass.sh --check

Entries like gitlab/cmesrobotics/camera_module are already in the cloned repo.
Do NOT type new GitLab tokens at the prompt — that would push wrong data.

EOF
    exit 1
}

require_any_gpg_key() {
    mapfile -t key_ids < <(gpg_secret_key_ids)
    if [[ ${#key_ids[@]} -gt 0 ]]; then
        echo ">> GPG secret key(s): ${key_ids[*]}"
        return 0
    fi
    cat >&2 <<'EOF'
ERROR: No GPG secret key on this machine.

  gpg --import /path/to/your-private-key.asc

EOF
    exit 1
}

pass_store_is_git_repo() {
    [[ -d "${PASS_STORE_DIR}/.git" ]]
}

pass_store_ready() {
    PASSWORD_STORE="${PASS_STORE_DIR}" pass ls >/dev/null 2>&1
}

team_entries_ready() {
    entry_valid "$PASS_CAMERA" && entry_valid "$PASS_CRP_CORE"
}

reset_local_store() {
    echo ">> removing ${PASS_STORE_DIR}"
    rm -rf "${PASS_STORE_DIR}"
}

clone_team_store() {
    # `pass git clone` fails if pass init left a non-git store; use git clone directly.
    if [[ -d "${PASS_STORE_DIR}" ]]; then
        reset_local_store
    fi
    echo ">> git clone team password-store"
    echo "   ${PASS_STORE_REPO}"
    echo "   → ${PASS_STORE_DIR}"
    echo "   (GitLab login may be required for HTTPS)"
    git clone "${PASS_STORE_REPO}" "${PASS_STORE_DIR}"
}

pull_team_store() {
    if ! pass_store_is_git_repo; then
        echo "ERROR: ${PASS_STORE_DIR} is not a git repo. Run ./setup-pass.sh first." >&2
        exit 1
    fi
    echo ">> git pull (${PASS_STORE_DIR})"
    PASSWORD_STORE="${PASS_STORE_DIR}" pass git pull 2>/dev/null \
        || git -C "${PASS_STORE_DIR}" pull
}

ensure_team_pass_store() {
    export PASSWORD_STORE="${PASS_STORE_DIR}"

    if pass_store_is_git_repo; then
        pull_team_store || true
        if team_entries_ready; then
            echo ">> pass store OK (${PASS_STORE_DIR})"
            return 0
        fi
        echo ">> git repo present but required entries missing or not decryptable"
        echo "   .gpg-id:"
        sed 's/^/     /' "${PASS_STORE_DIR}/.gpg-id" 2>/dev/null || true
        require_gpg_for_store
        exit 1
    fi

    require_any_gpg_key

    if [[ -d "${PASS_STORE_DIR}" ]]; then
        echo ">> ${PASS_STORE_DIR} exists but is not team git (pass init leftover)"
    fi

    read -rp "Clone team password-store from GitLab (replaces local store)? [Y/n] " ans
    if [[ "${ans,,}" == n ]]; then
        echo "Aborted. Manual: rm -rf ${PASS_STORE_DIR} && git clone ${PASS_STORE_REPO} ${PASS_STORE_DIR}" >&2
        exit 1
    fi

    clone_team_store
    require_gpg_for_store

    if ! pass_store_ready; then
        cat >&2 <<EOF
ERROR: cloned ${PASS_STORE_DIR} but cannot decrypt entries.

Your GPG key must be listed in .gpg-id:
$(sed 's/^/  /' "${PASS_STORE_DIR}/.gpg-id" 2>/dev/null || echo '  (missing)')

Import the correct CMES private key (not a newly generated key), then: ./setup-pass.sh --pull

EOF
        exit 1
    fi
}

# --- local-only fallback (not team workflow) ---

default_gpg_email() {
    git config --global user.email 2>/dev/null \
        || git config user.email 2>/dev/null \
        || echo "${USER}@$(hostname -f 2>/dev/null || hostname)"
}

create_gpg_key() {
    local email name uid
    email="$(default_gpg_email)"
    read -rp "GPG key email [$email]: " ans
    email="${ans:-$email}"
    name="CMES pass ($(whoami))"
    read -rp "GPG key label [$name]: " ans
    name="${ans:-$name}"
    uid="${name} <${email}>"

    echo ">> creating local GPG key (will NOT decrypt team password-store)"
    if ! gpg --batch --pinentry-mode loopback --passphrase '' \
            --quick-generate-key "$uid" rsa4096 default 0 2>/dev/null; then
        local batch
        batch="$(mktemp)"
        cat >"$batch" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${name}
Name-Email: ${email}
Expire-Date: 0
%commit
EOF
        gpg --batch --generate-key "$batch"
        rm -f "$batch"
    fi
}

setup_local_pass_store() {
    export PASSWORD_STORE="${PASS_STORE_DIR}"
    if pass_store_ready; then
        echo ">> local pass store already OK"
        return 0
    fi
    mapfile -t key_ids < <(gpg_secret_key_ids)
    if [[ ${#key_ids[@]} -eq 0 ]]; then
        read -rp "No GPG key. Create one for local-only store? [y/N] " ans
        [[ "${ans,,}" =~ ^y ]] || exit 1
        create_gpg_key
        mapfile -t key_ids < <(gpg_secret_key_ids)
    fi
    pass init "${key_ids[0]}"
}

entry_file_exists() {
    local entry=$1
    [[ -f "${PASS_STORE_DIR}/${entry}.gpg" ]]
}

entry_valid() {
    local entry=$1 line
    PASSWORD_STORE="${PASS_STORE_DIR}" pass show "$entry" >/dev/null 2>&1 || return 1
    line="$(PASSWORD_STORE="${PASS_STORE_DIR}" pass show "$entry" | sed -n '1p')"
    [[ -n "${line// }" ]]
}

entry_decrypt_failed() {
    local entry=$1
    entry_file_exists "$entry" && ! entry_valid "$entry"
}

check_entries() {
    local entry ok=1
    export PASSWORD_STORE="${PASS_STORE_DIR}"
    while IFS= read -r entry; do
        if entry_valid "$entry"; then
            echo ">> OK: $entry"
        elif entry_decrypt_failed "$entry"; then
            echo "ERROR: '$entry' is in the store but cannot decrypt (wrong GPG key)" >&2
            ok=0
        elif entry_file_exists "$entry"; then
            echo "ERROR: pass '$entry' exists but needs a 'login:' line" >&2
            ok=0
        else
            echo "ERROR: pass '$entry' not found in repo" >&2
            ok=0
        fi
    done < <(collect_pass_entries)
    if (( ok )); then
        echo ">> pass OK"
        return 0
    fi
    return 1
}

insert_entry_interactive() {
    local entry=$1 token user
    export PASSWORD_STORE="${PASS_STORE_DIR}"

    echo
    echo "=== $entry ==="
    echo "Team store should already contain this. Add only if missing from GitLab repo."
    echo

    if pass show "$entry" >/dev/null 2>&1; then
        read -rp "Entry exists. Overwrite? [y/N] " ans
        [[ "${ans,,}" =~ ^y ]] || return 0
        pass rm -f "$entry"
    fi

    read -rsp "GitLab token: " token; echo
    read -rp "GitLab username: " user
    pass insert -m "$entry" <<EOF
${token}
login: ${user}
EOF
    unset token user
    if pass_store_is_git_repo; then
        pass git push
    fi
}

setup_entries() {
    export PASSWORD_STORE="${PASS_STORE_DIR}"
    local entry

    if ! gpg_can_decrypt_store; then
        require_gpg_for_store
    fi

    while IFS= read -r entry; do
        if entry_decrypt_failed "$entry"; then
            require_gpg_for_store
        fi
    done < <(collect_pass_entries)

    while IFS= read -r entry; do
        if entry_valid "$entry"; then
            echo ">> OK: $entry"
            continue
        fi
        if entry_file_exists "$entry"; then
            echo "ERROR: '$entry' exists but format check failed (needs login: line)" >&2
            exit 1
        fi
        if pass_store_is_git_repo; then
            echo "ERROR: '$entry' not in team repo — ask admin to add it to password-store.git" >&2
            exit 1
        fi
        insert_entry_interactive "$entry"
    done < <(collect_pass_entries)
    check_entries
}

main() {
    case "$MODE" in
        install) install_pass_packages ;;
        pull)
            install_pass_packages
            require_gpg_for_store
            pull_team_store
            check_entries
            ;;
        local)
            install_pass_packages
            setup_local_pass_store
            setup_entries
            ;;
        check)
            command -v pass >/dev/null 2>&1 || {
                echo "ERROR: pass not installed. Run: ./setup-pass.sh" >&2
                exit 1
            }
            check_entries
            ;;
        setup)
            install_pass_packages
            ensure_team_pass_store
            setup_entries
            echo
            echo ">> Next: make build"
            ;;
    esac
}

main
