#!/usr/bin/env bash
# Git hooks tasks
set -euo pipefail

task="${1:-}"
shift || {
    echo "Usage: $0 <forbid-tabs|remove-tabs|no-commit-to-branch> [file...]" >&2
    exit 1
}

# A literal tab character, built portably — avoids relying on GNU-only \t
# escapes, since BSD/macOS grep and sed don't interpret \t the same way.
tab="$(printf '\t')"

forbid_tabs() {
    if [ "$#" -eq 0 ]; then
        exit 0 # nothing to check
    fi

    local rc=0
    if command -v rg >/dev/null 2>&1; then
        rg -l --fixed-strings -e "$tab" -- "$@" || rc=$?
    else
        grep -lF -- "$tab" "$@" 2>/dev/null || rc=$?
    fi

    case "$rc" in
    0)
        echo "Tabs found in file(s) above."
        exit 1
        ;;
    1)
        exit 0 # no matches — clean
        ;;
    *)
        echo "Search failed (exit $rc) while scanning for tabs." >&2
        exit "$rc"
        ;;
    esac
}

remove_tabs() {
    if [ "$#" -eq 0 ]; then
        exit 0 # nothing to fix
    fi

    local file backup
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "Skipping missing file: $file" >&2
            continue
        fi
        backup="${file}.bak"
        # -i.bak works identically on GNU and BSD sed; only the .bak suffix's
        # attachment style differs, and this form is accepted by both.
        sed -i.bak "s/${tab}/    /g" "$file"
        rm -f -- "$backup" # remove only the backup we just made, not a repo-wide sweep
    done
}

no_commit_to_branch() {
    local branch
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

    if [ "$branch" = "devel" ] || printf '%s' "$branch" | grep -Eq '^RELEASE.*'; then
        echo "Direct commits to '$branch' are not allowed."
        exit 1
    fi
}

case "$task" in
forbid-tabs)
    forbid_tabs "$@"
    ;;
remove-tabs)
    remove_tabs "$@"
    ;;
no-commit-to-branch)
    no_commit_to_branch
    ;;
*)
    echo "Unknown task: $task" >&2
    exit 1
    ;;
esac
