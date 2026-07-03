#!/usr/bin/env Rscript
# R package description tasks
#
# Usage:
#   Rscript --vanilla tools/r-package-description.R tidy-description-check
#   Rscript --vanilla tools/r-package-description.R tidy-description-fix

if (file.exists("renv/activate.R")) {
     source("renv/activate.R")
   }

quit_with <- function(status) {
  quit(save = "no", status = status, runLast = FALSE)
}

require_desc <- function() {
  if (!requireNamespace("desc", quietly = TRUE)) {
    message("The 'desc' package is required but not installed.")
    quit_with(1)
  }
}

require_description_file <- function() {
  if (!file.exists("DESCRIPTION")) {
    message("No DESCRIPTION file found in the current directory.")
    quit_with(1)
  }
}

tidy_description_check <- function() {
  require_desc()
  require_description_file()

  d <- desc::desc()
  before <- format(d)
  d$normalize()
  after <- format(d)

  if (!identical(before, after)) {
    message("DESCRIPTION is not tidy. Run `mise run tidy-description-fix`.")
    quit_with(1)
  }

  quit_with(0)
}

tidy_description_fix <- function() {
  require_desc()
  require_description_file()

  desc::desc_normalize()
  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""

  switch(task,
    "tidy-description-check" = tidy_description_check(),
    "tidy-description-fix" = tidy_description_fix(),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-package-description.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
