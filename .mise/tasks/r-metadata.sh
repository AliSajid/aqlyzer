#!/bin/bash
# R package metadata tasks

case "$1" in
  codemeta)
    Rscript --vanilla -e 'codemetar::write_codemeta()'
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac