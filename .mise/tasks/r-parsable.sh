#!/bin/bash
# R package parsable check tasks

case "$1" in
  parsable)
    Rscript --vanilla -e '
      files <- commandArgs(trailingOnly = TRUE)
      bad <- Filter(function(f) inherits(tryCatch(parse(f), error = function(e) e), "error"), files)
      if (length(bad) > 0) {
        cat("Failed to parse:\n", paste(" -", bad, collapse = "\n"), "\n")
        quit(status = 1)
      }
    ' --args "$@"
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac