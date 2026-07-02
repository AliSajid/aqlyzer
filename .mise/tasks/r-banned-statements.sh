#!/bin/bash
# R package banned statements tasks

case "$1" in
  no-browser)
    if grep -nE '\bbrowser\(\)' "$@"; then
      echo "Found browser() statement(s) above."
      exit 1
    fi
    ;;

  no-debug)
    if grep -nE '\b(debug|debugonce)\(' "$@"; then
      echo "Found debug()/debugonce() statement(s) above."
      exit 1
    fi
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac