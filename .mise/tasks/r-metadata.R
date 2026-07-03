#!/usr/bin/env Rscript
# R package metadata tasks
#
# Usage:
#   Rscript tools/r-package-metadata.R codemeta

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

require_codemetar <- function() {
  if (!requireNamespace("codemetar", quietly = TRUE)) {
    message("The 'codemetar' package is required but not installed.")
    quit_with(1)
  }
}

require_description_file <- function() {
  if (!file.exists("DESCRIPTION")) {
    message("No DESCRIPTION file found in the current directory.")
    quit_with(1)
  }
}

codemeta <- function() {
  require_codemetar()
  require_description_file()

  codemetar::write_codemeta()
  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""

  switch(task,
    "codemeta" = codemeta(),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-package-metadata.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
