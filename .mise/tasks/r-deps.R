#!/usr/bin/env Rscript
# R package dependencies check task
#
# Usage:
#   Rscript --vanilla tools/r-package-deps.R deps-in-desc
#
# Static, best-effort check that every package referenced via library()/
# require()/requireNamespace()/loadNamespace() or the pkg::fun / pkg:::fun
# forms in R/*.R is actually declared in DESCRIPTION (Depends/Imports/
# LinkingTo). This is a heuristic, not a substitute for R CMD check.

if (file.exists("renv/activate.R")) {
     source("renv/activate.R")
   }

quit_with <- function(status) {
  quit(save = "no", status = status, runLast = FALSE)
}

extract_used_packages <- function(file) {
  txt <- tryCatch(
    paste(readLines(file, warn = FALSE), collapse = "\n"),
    error = function(e) {
      message(sprintf("Could not read %s: %s", file, conditionMessage(e)))
      ""
    }
  )
  if (!nzchar(txt)) {
    return(character(0))
  }

  # library(pkg), library("pkg"), require(pkg), requireNamespace("pkg"),
  # loadNamespace("pkg") — quotes optional, matching either style
  call_pattern <- "(?:library|require|requireNamespace|loadNamespace)\\(\\s*['\"]?([[:alnum:].]+)['\"]?"
  call_matches <- regmatches(txt, gregexpr(call_pattern, txt, perl = TRUE))[[1]]
  call_pkgs <- sub(call_pattern, "\\1", call_matches, perl = TRUE)

  # pkg::fun and pkg:::fun
  ns_pattern <- "[[:alnum:].]+(?=:::?[[:alnum:].]+)"
  ns_pkgs <- regmatches(txt, gregexpr(ns_pattern, txt, perl = TRUE))[[1]]

  unique(c(call_pkgs, ns_pkgs))
}

deps_in_desc <- function() {
  if (!requireNamespace("desc", quietly = TRUE)) {
    message("The 'desc' package is required but not installed.")
    quit_with(1)
  }

  r_dir <- "R"
  if (!dir.exists(r_dir)) {
    message("No 'R/' directory found -- nothing to check.")
    quit_with(0)
  }

  r_files <- list.files(r_dir, pattern = "\\.[Rr]$", full.names = TRUE, recursive = TRUE)
  if (length(r_files) == 0) {
    quit_with(0)
  }

  used <- sort(unique(unlist(lapply(r_files, extract_used_packages))))

  deps <- desc::desc_get_deps()
  declared <- deps$package[deps$type %in% c("Depends", "Imports", "LinkingTo")]

  base_pkgs <- c("base", "methods", "stats", "utils", "graphics", "grDevices", "datasets", "tools")

  missing <- setdiff(used, c(declared, base_pkgs))

  if (length(missing) > 0) {
    cat("Packages used but not declared in DESCRIPTION (Depends/Imports/LinkingTo):\n")
    cat(paste(" -", missing), sep = "\n")
    quit_with(1)
  }

  quit_with(0)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  task <- if (length(args) >= 1) args[[1]] else ""

  switch(task,
    "deps-in-desc" = deps_in_desc(),
    {
      message(sprintf("Unknown task: %s", task))
      quit_with(1)
    }
  )
}

tryCatch(
  main(),
  error = function(e) {
    message(sprintf("r-package-deps.R failed: %s", conditionMessage(e)))
    quit_with(1)
  }
)
