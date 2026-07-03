#!/usr/bin/env Rscript
# R package readme tasks
#
# Usage:
#   Rscript tools/r-package-readme.R readme-check
#   Rscript tools/r-package-readme.R readme-fix

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

require_rmarkdown <- function() {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    message("The 'rmarkdown' package is required but not installed.")
    quit_with(1)
  }
}

render_readme <- function() {
  rmarkdown::render("README.Rmd", quiet = TRUE)
}

readme_check <- function() {
  if (!file.exists("README.Rmd")) {
    quit_with(0) # nothing to check
  }

  require_rmarkdown()

  had_original <- file.exists("README.md")
  backup <- NULL
  if (had_original) {
    # tempfile() gives a unique per-process path, unlike a fixed /tmp name,
    # so concurrent runs (different repos, parallel hk steps) can't collide.
    backup <- tempfile(fileext = ".md")
    file.copy("README.md", backup, overwrite = TRUE)
  }

  render_readme()

  out_of_date <- !had_original || !identical(
    readLines("README.md", warn = FALSE),
    readLines(backup, warn = FALSE)
  )

  if (had_original) {
    # restore the working tree to how it was before this check ran
    file.copy(backup, "README.md", overwrite = TRUE)
    unlink(backup)
  }

  if (out_of_date) {
    message("README.md is out of date with README.Rmd. Run `mise run readme-fix`.")
    quit_with(1)
  }

  quit_with(0)
}

readme_fix <- function() {
  if (!file.exists("README.Rmd")) {
    quit_with(0) # nothing to render
  }

  require_rmarkdown()
  render_readme()
  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""

  switch(task,
    "readme-check" = readme_check(),
    "readme-fix" = readme_fix(),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-package-readme.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
