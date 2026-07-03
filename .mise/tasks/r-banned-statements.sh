#!/usr/bin/env bash
# R package banned statements task
set -euo pipefail

task="${1:-}"
shift || {
    echo "Usage: $0 <no-browser|no-debug> <file>..." >&2
    exit 1
}

# Prefer ripgrep; fall back to grep if it isn't on PATH.
search() {
    local pattern="$1"
    shift
    if command -v rg >/dev/null 2>&1; then
        rg -n --no-heading -e "$pattern" -- "$@"
    else
        grep -nE "$pattern" -- "$@"
    fi
}

check() {
    local pattern="$1" message="$2"
    shift 2

    if [ "$#" -eq 0 ]; then
        exit 0 # nothing to check
    fi

    local rc=0
    search "$pattern" "$@" || rc=$?

    case "$rc" in
    0)
        echo "$message" >&2
        exit 1
        ;;
    1)
        exit 0 # no matches — clean
        ;;
    *)
        echo "Search failed (exit $rc) while scanning for '$pattern'." >&2
        exit "$rc"
        ;;
    esac
}

case "$task" in
no-browser)
    check '\bbrowser\(\)' "Found browser() statement(s) above." "$@"
    ;;
no-debug)
    check '\b(debug|debugonce)\(' "Found debug()/debugonce() statement(s) above." "$@"
    ;;
*)
    echo "Unknown task: $task" >&2
    exit 1
    ;;
esac
