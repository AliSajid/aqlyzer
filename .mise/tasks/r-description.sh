#!/bin/bash
# R package description tasks

case "$1" in
  tidy-description-check)
    Rscript --vanilla -e '
      d <- desc::desc()
      before <- format(d)
      d$normalize()
      after <- format(d)
      if (!identical(before, after)) {
        cat("DESCRIPTION is not tidy. Run `mise run r-tidy-description-fix`.\n")
        quit(status = 1)
      }
    '
    ;;

  tidy-description-fix)
    Rscript --vanilla -e 'desc::desc_normalize()'
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac