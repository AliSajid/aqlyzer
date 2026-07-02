#!/bin/bash
# R package style and lint tasks

case "$1" in
style)
    Rscript --vanilla -e "styler::style_pkg(transformers = biocthis::bioc_style())"
    ;;

lint)
    Rscript --vanilla -e "lintr::lint_package()"
    ;;

*)
    echo "Unknown task: $1"
    exit 1
    ;;
esac
