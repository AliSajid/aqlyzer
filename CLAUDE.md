# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`aqlyzer` is an R package (targeting Bioconductor) for analysing time-resolved
fluorescence kinetics data from 96-well plate readers. Performance-critical
work (linear range detection) is implemented in Rust via **extendr**, with a
pure-R fallback. R >= 4.6; Rust >= 1.65 (Cargo required to build from source).

The package serves two audiences from one codebase: a set of **reusable,
documented functions** for R programmers, and a **Shiny application** (bundled in
the same package) that wraps those functions for push-button use by non-programmers.
Keep the analysis logic in exported functions — the Shiny app should call them,
not reimplement them.

## Architecture

The R/Rust boundary is the central thing to understand:

- `R/linear_range.R` — public API. `findLinearRange()` dispatches at runtime:
  `isRustAvailable()` checks whether the compiled `findLinearRangeRust` exists;
  if so it calls the Rust backend, otherwise it falls back to `findLinearRangeR()`
  (same algorithm, slower). Input validation (`stopifnot`) lives in the dispatcher.
- `src/rust/src/lib.rs` — the Rust implementation (`#[extendr]` functions and the
  `extendr_module!` registration). This is the source of truth for the compiled backend.
- `R/extendr-wrappers.R` — **generated, do not hand-edit.** Produced by
  `rextendr::document()` from the Rust annotations. Regenerate after any change to
  the Rust signatures/roxygen. This also updates `NAMESPACE` and `man/`.
- `src/Makevars.in` / `configure` / `tools/config.R` — compile the Rust static lib
  (`libaqlyzer.a`) and link it into the R shared object. `configure` runs
  `tools/config.R`; `tools/msrv.R` reports the Rust toolchain version for CRAN/Bioc.

Both R and Rust indices are returned **1-based** (the Rust code converts from its
0-based internals before returning to R). Keep this invariant when editing either side.

## Common commands

Standard R package development (run from the repo root, R console or `Rscript`):

```r
rextendr::document()   # regenerate Rust wrappers + roxygen docs + NAMESPACE (run after Rust or roxygen edits)
devtools::load_all()   # compile Rust + load the package for interactive work
devtools::test()       # run the full testthat suite (edition 3)
devtools::check()      # R CMD check
testthat::test_file("tests/testthat/test-linear_range.R")  # single test file
```

CI runs Bioconductor checks (`.github/workflows/check-bioc.yml`), including `BiocCheck`.

## Conventions (enforced — match them or the pre-commit hooks will fail)

- **camelCase** for object and function names — enforced by `object_name_linter` in
  `.lintr`. This (and the other non-idiomatic R choices here) is required to satisfy
  **Bioconductor** package conventions, not a stylistic preference — follow it. Both R
  and Rust functions use camelCase (`findLinearRangeRust`, `minPoints`).
- **4-space indentation**, 120-char line limit (styler tidyverse style, `indent_by = 4`).
- **Conventional Commits** are required (`commit-msg` hook). Allowed types:
  `build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test, bump`.
- No `browser()`/`debug()` statements; no committing `.Rhistory`/`.RData`/`.Rds`.

## Tooling: hk + mise (not the usual R precommit)

Git hooks are driven by **hk** (`hk.pkl`), with all custom logic implemented as
**mise** tasks in `.mise/tasks/` and invoked via `mise run <task>`. `mise.toml`
pins `hk`, `typos-cli`, and `jq`; `mise run <...>` postinstall wires up the hooks.

The pre-commit chain also **auto-bumps the package version** (`bump-version` task,
touching `DESCRIPTION`) and regenerates `codemeta`; the post-commit hook auto-creates
a version tag. Do **not** manually edit the version in `DESCRIPTION` — let the hook
handle it.
