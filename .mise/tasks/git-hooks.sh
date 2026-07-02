#!/bin/bash
# Git hooks tasks

case "$1" in
forbid-tabs)
    if grep -PlR '\t' "$@" 2>/dev/null; then
        echo "Tabs found in file(s) above."
        exit 1
    fi
    ;;

remove-tabs)
    sed -i.bak "s/\t/    /g" "$@" && find . -name "*.bak" -delete
    ;;

no-commit-to-branch)
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$branch" = "devel" ] || echo "$branch" | grep -Eq '^RELEASE.*'; then
        echo "Direct commits to '$branch' are not allowed."
        exit 1
    fi
    ;;

*)
    echo "Unknown task: $1"
    exit 1
    ;;
esac
