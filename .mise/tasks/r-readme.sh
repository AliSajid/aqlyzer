#!/bin/bash
# R package readme tasks

case "$1" in
  readme-check)
    if [ -f README.Rmd ]; then
      cp README.md /tmp/README.md.orig
      Rscript --vanilla -e 'rmarkdown::render("README.Rmd", quiet = TRUE)'
      if ! diff -q README.md /tmp/README.md.orig > /dev/null; then
        cp /tmp/README.md.orig README.md
        echo "README.md is out of date with README.Rmd. Run \`mise run r-readme-fix\`."
        exit 1
      fi
    fi
    ;;

  readme-fix)
    Rscript --vanilla -e 'if (file.exists("README.Rmd")) rmarkdown::render("README.Rmd", quiet = TRUE)'
    ;;

  *)
    echo "Unknown task: $1"
    exit 1
    ;;
esac