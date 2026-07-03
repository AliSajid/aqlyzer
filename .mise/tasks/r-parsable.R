#!/usr/bin/env Rscript
# R package parsable check task
#
# Usage:
#   Rscript tools/r-parsable.R parsable file1.R file2.R ...

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

parsable <- function(files) {
  if (length(files) == 0) {
    quit_with(0) # nothing to check
  }

  bad <- Filter(function(f) {
    if (!file.exists(f)) {
      message(sprintf("Skipping missing file: %s", f))
      return(FALSE)
    }
    inherits(tryCatch(parse(f), error = function(e) e), "error")
  }, files)

  if (length(bad) > 0) {
    cat("Failed to parse:\n")
    cat(paste(" -", bad), sep = "\n")
    quit_with(1)
  }

  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""
  rest <- if (length(args) >= 2) args[-1] else character(0)

  switch(task,
    "parsable" = parsable(rest),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-parsable.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
