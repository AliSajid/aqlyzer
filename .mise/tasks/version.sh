#!/bin/bash
# Version management tasks

case "$1" in
  bump-version)
    ./tools/bump-version.sh
    ;;

  create-version-tag)
    ./tools/create-tag.sh
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac