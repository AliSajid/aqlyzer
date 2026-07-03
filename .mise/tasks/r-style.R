#!/usr/bin/env Rscript
# R package style and lint tasks
#
# Usage:
#   Rscript tools/r-package-style.R style
#   Rscript tools/r-package-style.R lint

# Defensive renv activation: plain `Rscript` already sources .Rprofile (and
# so renv's autoloader) as long as the working directory is the project
# root. This guard covers the case where it isn't, or where --vanilla /
# --no-init-file gets passed by whatever calls this script later.
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

quit_with <- function(status) {
  quit(save = "no", status = status, runLast = FALSE)
}

require_packages <- function(...) {
  pkgs <- c(...)
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    message(sprintf("Required package(s) not installed: %s", paste(missing, collapse = ", ")))
    quit_with(1)
  }
}

require_description_file <- function() {
  if (!file.exists("DESCRIPTION")) {
    message("No DESCRIPTION file found in the current directory -- is this a package root?")
    quit_with(1)
  }
}

style <- function() {
  require_packages("styler", "biocthis")
  require_description_file()

  styler::style_pkg(transformers = biocthis::bioc_style())
  quit_with(0)
}

lint <- function() {
  require_packages("lintr")
  require_description_file()

  lints <- lintr::lint_package()

  # lint_package() just returns a "lints" object -- it never signals failure
  # on its own, so the original script always exited 0 regardless of how
  # many lints were found. Checking length() here is what actually makes
  # this behave like a check.
  if (length(lints) > 0) {
    print(lints)
    message(sprintf("Found %d lint(s).", length(lints)))
    quit_with(1)
  }

  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""

  switch(task,
    "style" = style(),
    "lint" = lint(),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-package-style.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
