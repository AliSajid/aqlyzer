#!/bin/bash
# R package dependencies check task

case "$1" in
deps-in-desc)
    Rscript --vanilla -e '
      used <- unique(unlist(lapply(list.files("R", pattern = "\\.[Rr]$", full.names = TRUE), function(f) {
        txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
        m1 <- regmatches(txt, gregexpr("(?<=library\\()[[:alnum:].]+", txt, perl = TRUE))[[1]]
        m2 <- regmatches(txt, gregexpr("[[:alnum:].]+(?=::)", txt, perl = TRUE))[[1]]
        unique(c(m1, m2))
      })))
      declared <- names(desc::desc_get_deps()[desc::desc_get_deps()$type %in% c("Imports", "Depends"), "package"])
      declared <- desc::desc_get_deps()$package
      missing <- setdiff(used, c(declared, "base", "methods", "stats", "utils"))
      if (length(missing) > 0) {
        cat("Packages used but not declared in DESCRIPTION:\n", paste(" -", missing, collapse = "\n"), "\n")
        quit(status = 1)
      }
    '
    ;;

*)
    echo "Unknown task: $1"
    exit 1
    ;;
esac
