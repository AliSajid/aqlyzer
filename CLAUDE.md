# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code
in this repository.

---

## What this is

`aqlyzer` is an R package (targeting Bioconductor) for analysing time-resolved
fluorescence kinetics data from 96-well plate readers. The assay measures kinase
activity using the AssayQuant system. Sample material is entirely
experiment-defined — postmortem brain, pleural fluid, cell lysate, or anything
else — and the package makes no assumptions about it beyond what the user declares
in the plate layout. The only guaranteed well type in every valid run is the
**AssayQuant (AQ) peptide**, which serves as the pipeline's anchor for QC and
signal plausibility checks.

Data are bounded: 96 wells maximum, ≤4 hours reaction time (~120 time points).
The full pipeline completes in under 2 seconds; no async workers or parallel
backends are needed.

Performance-critical work (linear range detection) is implemented in Rust via
**extendr**, with a pure-R fallback. R >= 4.6; Rust >= 1.65 (Cargo required to
build from source).

The package serves two audiences from one codebase:

- **R programmers** — reusable, documented, testable exported functions callable
  directly from scripts or other packages.
- **Non-programmers** — a Shiny application launched via `aqlyzerApp()` that wraps
  those same functions for push-button, upload-and-run use.

**The cardinal rule:** analysis logic lives in exported package functions. The
Shiny app is a UI shell that calls them. Nothing in the Shiny layer reimplements
analysis. If logic is only in the app, it belongs in the package instead.

### DESCRIPTION fields

```
Title: Fluorescence Kinetics Analysis for Microplate Assays
biocViews: Software, Proteomics, CellBasedAssays, Preprocessing,
    QualityControl, StatisticalMethod, Regression, Visualization, DataImport
```

---

## Architecture

Three layers. The Shiny layer calls into the R package layer; the R package layer
optionally delegates to the Rust layer.

```
┌──────────────────────────────────────────────────────────────┐
│  Shiny application   R/app.R + R/mod_*.R                     │
│                                                              │
│  aqlyzerApp() → shinyApp(aqlyzerUi(), aqlyzerServer)         │
│                                                              │
│  mod_upload.R · mod_plate_editor.R · mod_results.R           │
└──────────────────────────────┬───────────────────────────────┘
                               │ module servers call package API
┌──────────────────────────────▼───────────────────────────────┐
│  R package core   R/                                         │
│                                                              │
│  Pipeline:  preprocessRun() ──► processSignals()             │
│                                       └──► fitModels()       │
│                                                              │
│  Layout:    validateLayout() · checkLayoutPlausibility()     │
│  Output:    ggplot2 helpers  · provenance / hashing          │
│  Backend:   findLinearRange() dispatcher                     │
└──────────────────────────────┬───────────────────────────────┘
                               │ optional — R fallback if absent
┌──────────────────────────────▼───────────────────────────────┐
│  Rust native extension   src/rust/src/lib.rs                 │
│  findLinearRangeRust()                                       │
└──────────────────────────────────────────────────────────────┘
```

### R/Rust boundary

- `R/linear_range.R` — public API. `findLinearRange()` dispatches at runtime:
  `isRustAvailable()` checks whether compiled `findLinearRangeRust` exists; if so
  it calls the Rust backend, otherwise falls back to `findLinearRangeR()` (same
  algorithm, slower). Input validation (`stopifnot`) lives in the dispatcher only —
  never duplicated in either backend.
- `src/rust/src/lib.rs` — Rust implementation (`#[extendr]` functions and the
  `extendr_module!` registration). Source of truth for the compiled backend.
- `R/extendr-wrappers.R` — **generated, do not hand-edit.** Produced by
  `rextendr::document()` from the Rust annotations. Regenerate after any change to
  Rust signatures or roxygen comments. This also updates `NAMESPACE` and `man/`.
- `src/Makevars.in` / `configure` / `tools/config.R` — compile the Rust static lib
  (`libaqlyzer.a`) and link into the R shared object. `configure` runs
  `tools/config.R`; `tools/msrv.R` reports the Rust toolchain version for CRAN/Bioc.

Both R and Rust functions return indices **1-based** (Rust converts from its 0-based
internals before returning). Maintain this invariant on both sides of every change.

---

## Directory structure

Current state of the repository, annotated:

```
aqlyzer/
├── DESCRIPTION
├── NAMESPACE                        # managed by roxygen2 + rextendr — do not edit
├── NEWS.md
├── README.Rmd
│
├── R/
│   ├── extendr-wrappers.R           # generated — never edit by hand
│   ├── linear_range.R               # findLinearRange() dispatcher + R fallback ✓ exists
│   │
│   │   # ── to be added ──────────────────────────────────────────────────
│   ├── preprocess.R                 # preprocessRun()
│   ├── signals.R                    # processSignals()
│   ├── models.R                     # fitModels()
│   ├── plate_layout.R               # validateLayout(), checkLayoutPlausibility()
│   ├── plots.R                      # ggplot2 QC and results helpers
│   ├── utils.R                      # shared helpers, provenance, hashing
│   ├── app.R                        # aqlyzerApp(), aqlyzerUi() (internal), aqlyzerServer (internal)
│   ├── mod_upload.R                 # uploadUi() / uploadServer()
│   ├── mod_plate_editor.R           # plateEditorUi() / plateEditorServer()
│   └── mod_results.R                # resultsUi() / resultsServer()
│
├── src/
│   ├── Makevars / Makevars.in / Makevars.win.in
│   ├── entrypoint.c
│   └── rust/
│       ├── Cargo.toml
│       ├── Cargo.lock
│       ├── document.rs
│       └── src/
│           └── lib.rs               # findLinearRangeRust() ✓ exists
│
├── inst/
│   ├── CITATION
│   └── extdata/
│       ├── example_run_data.xlsx      # example instrument RFU export
│       └── example_plate_layout.xlsx  # example plate layout (anonymized)
│
├── tests/
│   └── testthat/
│       ├── test-example_test.R      # placeholder ✓ exists
│       ├── test-linear_range.R      # ✓ exists
│       │   # ── to be added ──────────────────────────────────────────────
│       ├── test-preprocess.R
│       ├── test-signals.R
│       ├── test-models.R
│       ├── test-plate_layout.R
│       ├── test-app.R               # shiny::testServer() module tests
│       └── test-integration.R       # full pipeline from extdata to results
│
├── vignettes/
│   └── aqlyzer.Rmd
│
├── dev/                             # non-package development scripts, not installed
│   ├── 01_create_pkg.R
│   ├── 02_git_github_setup.R
│   ├── 03_core_files.R
│   └── 04_update.R
│
├── tools/
│   ├── config.R                     # Rust build configuration
│   └── msrv.R                       # reports minimum supported Rust version
│
├── configure / configure.win
├── hk.pkl                           # hk hook definitions
└── mise.toml                        # pins hk, typos-cli, jq; defines mise tasks
```

> Access example data with:
> `system.file("extdata", "example_run_data.xlsx", package = "aqlyzer")`

---

## Plate layout

### Design principle

Sample identity is entirely user-defined. The pipeline only needs to know the
**role** each well plays in the assay — the `sampleType` column provides that.
Everything else (`group`, `displayLabel`) is metadata that flows through to outputs
and plots but does not affect signal processing logic.

### The `plateLayoutDf` contract

One row per well. This single tibble replaces both the hardcoded `coords_table`
(cell ranges) and the `case_when` block (well→label mapping) from the original
scripts. Those encoded the same information twice; this is the single source of truth.

| Column | Type | Description |
|---|---|---|
| `well` | chr | Well address `"A1"` … `"H12"` |
| `sampleId` | chr | Unique sample identifier, user-defined |
| `sampleType` | chr | Pipeline role — **controlled vocabulary** (see below) |
| `group` | chr | Experimental group, **free-form**, user-defined (e.g. `"SCZ"`, `"CTL"`, `"pleural_fluid"`, `"PBMC"`). `NA` is valid for wells that need no grouping. |
| `inhibited` | lgl | Kinase inhibitor added to this well |
| `heatInactivated` | lgl | Sample was heat-inactivated |
| `displayLabel` | chr | Optional human-readable label for plots and tables. Falls back to `sampleId` if `NA`. |

Derived columns (`Condition`, `Substrate`) from the old scripts are gone —
they were experiment-specific encodings. `sampleId`, `group`, and `displayLabel`
carry that information in a general form.

### `sampleType` controlled vocabulary

This is the only column the pipeline logic branches on. Extend this list only
when a new well role genuinely changes processing behaviour, and update
`validateLayout()` in the same commit.

| Value | Meaning | Pipeline use |
|---|---|---|
| `"aqPeptide"` | AssayQuant detection peptide | **Required in every run.** Primary QC anchor. Signal plausibility is assessed relative to these wells. |
| `"blank"` | No-lysate blank (e.g. M-PER, PBS, buffer) | Required for blank subtraction. The specific reagent is irrelevant to the pipeline; the role is what matters. |
| `"sample"` | Experimental sample (any matrix) | Receives zeroing, blank subtraction, replicate averaging, model fitting. |
| `"inhibited"` | Sample + kinase inhibitor | Processed identically to `"sample"`. Used in plausibility checks: slope should be near zero. May be combined with `inhibited = TRUE` flag for downstream filtering. |
| `"heatInactivated"` | Heat-inactivated sample | Processed identically to `"sample"`. Slope expected near zero; flagged if not. |

`inhibited` and `heatInactivated` logical flags exist in addition to the `sampleType`
column because a well can be `sampleType = "sample"` with `inhibited = TRUE` (an
inhibited experimental sample) or `sampleType = "inhibited"` as a standalone
inhibitor-only control. Both patterns are valid; use whichever matches the plate design.

### Well renaming and display labels

Users can rename any well for display purposes without changing its `sampleId` or
`sampleType`. The `displayLabel` column flows through to all plot axis labels,
table row names, and the results `.RDS`. Changing a `displayLabel` never affects
signal processing. This is the intended mechanism for:

- Renaming an AQ peptide replicate from `"AQLYS_1"` to `"AQ Peptide (rep 1)"`.
- Labelling a sample `"Patient 042 — pleural fluid"` without encoding that in `sampleId`.
- Anonymising sample IDs in exported figures.

The plate editor in the Shiny app exposes `displayLabel` as an editable column
alongside the well grid.

---

## Validation layers

### Layer 1 — Structural (`validateLayout()`, hard errors, blocking)

Run at layout submission before any analysis. Errors are returned as a named list
of character vectors (not thrown), so the Shiny UI can render them as inline
messages and the Run button remains disabled.

Checks (in order):
1. **Required columns present** — `well`, `sampleId`, `sampleType`, `inhibited`,
   `heatInactivated` must all exist.
2. **Bidirectional well-set match** — `layout$well` and wells detected in the data
   file must be identical sets. Catches reused layouts from different run files.
3. **No duplicate wells** — each well address appears at most once.
4. **No missing required fields** — `well`, `sampleId`, `sampleType` must be non-NA
   for every row. `group` and `displayLabel` may be `NA`.
5. **Controlled vocabulary** — `sampleType` values must be in the known set.
6. **Minimum design** — at least one `"aqPeptide"` well (always required) and at
   least one `"blank"` well (blank subtraction cannot proceed without it).

### Layer 2 — Signal plausibility (`checkLayoutPlausibility()`, soft warnings)

Run after `preprocessRun()`, before `processSignals()`. Returns a tibble of
warnings keyed by `well` — not errors, not thrown. Shiny renders these as icons
overlaid on the well grid.

| Check | Trigger | Well types checked |
|---|---|---|
| Elevated blank | Mean signal > 3× median of all blank signals | `"blank"` |
| Active inhibited well | `lm` slope above threshold | `sampleType == "inhibited"` or `inhibited == TRUE` |
| Active heat-inactivated well | `lm` slope above threshold | `heatInactivated == TRUE` |
| Replicate divergence | Pairwise r² < 0.90 for same `sampleId` | All types |
| Flat non-control well | `var(Signal) ≈ 0` and not blank/HI/inhibited | `"sample"`, `"aqPeptide"` |
| AQ peptide signal absent | AQ peptide wells show no rise from baseline | `"aqPeptide"` |

### Layer 3 — Visual confirmation gate (Shiny UI)

After structural validation passes, the plate editor shows the colour-coded 8×12
grid. Plausibility warnings from Layer 2 overlay as icons on affected wells. The
**Run Analysis** button is gated behind an explicit acknowledgement checkbox:
*"I have verified the plate layout against the bench record."* This is the primary
defence against running with a layout copied from a prior experiment.

### Layer 4 — Provenance (embedded in all outputs)

Every results object carries the layout and file hashes that produced it:

```r
list(
  params           = modelParamsDf,
  preprocessed     = preprocessedDf,
  layout           = plateLayoutDf,           # verbatim
  layoutHash       = digest::digest(plateLayoutDf, algo = "sha256"),
  dataHash         = digest::digest(rawData,        algo = "sha256"),
  runTimestamp     = Sys.time(),
  pkgVersion       = packageVersion("aqlyzer")
)
```

Do not strip hashes from serialised outputs. They are how you prove which file
produced which result six months later.

---

## Pipeline — core functions

All three pipeline functions are pure: they take data in, return data out, and
perform no file I/O. File reading and writing are the caller's responsibility
(or the Shiny module's). This makes every stage independently unit-testable.

### `preprocessRun(dataFile, plateLayout)` — `R/preprocess.R`

Replaces `preprocess_run9.R`.

Reads the instrument XLSX (wells as columns, time points as rows, time in Excel
serial days), pivots to long form, and joins the plate layout. The old
`coords_table` (hardcoded cell ranges) and `case_when` block (well→label mapping)
are entirely replaced by the `plateLayout` argument.

**Inputs:**
- `dataFile` — path to instrument XLSX. Time is Excel serial days;
  conversion: `as.numeric(Time) * 86400L` → seconds.
- `plateLayout` — a validated `plateLayoutDf`.

**Output tibble columns:**

| Column | Type | Notes |
|---|---|---|
| `Well` | chr | `"A1"` … `"H12"` |
| `Row` | chr | Single letter `A`–`H` |
| `Col` | int | 1–12 |
| `SampleId` | chr | From layout |
| `SampleType` | chr | From layout |
| `Group` | chr | From layout — may be `NA` |
| `DisplayLabel` | chr | From layout `displayLabel`, falls back to `SampleId` |
| `Inhibited` | lgl | From layout |
| `HeatInactivated` | lgl | From layout |
| `ElapsedTime` | dbl | Seconds |
| `Signal` | int | Raw RFU |

### `processSignals(preprocessedDf)` — `R/signals.R`

Replaces `process_signaldata_experimental.R`.

Three steps, in order:

1. **Zero** — subtract each well's signal at `ElapsedTime == 0` from all its
   time points.
2. **Blank subtract** — identify wells where `sampleType == "blank"`, average
   their zeroed signal at each time point, subtract from all non-blank wells. The
   specific blank reagent (M-PER, PBS, etc.) is irrelevant; `sampleType` is
   the selector.
3. **Replicate average** — group by `(SampleId, SampleType, Group, Inhibited,
   HeatInactivated, DisplayLabel, ElapsedTime)`, compute `mean(Signal, na.rm = TRUE)`.
   Well-level columns (`Well`, `Row`, `Col`) are dropped after averaging.

**Output:** Averaged tibble. Columns are the Stage 1 output minus `Well`, `Row`,
`Col`. One row per `(SampleId, ElapsedTime)`.

### `fitModels(averagedDf)` — `R/models.R`

Replaces `fit_linear_models.R`.

For each `(SampleId, Group)`:
1. Convert `ElapsedTime` to minutes.
2. Call `findLinearRange(signal, times)` → `(start, end, score)`.
3. Fit `lm(Signal ~ ElapsedTime)` on the linear-range slice → `LinearDataModel`.
4. Fit `lm(Signal ~ ElapsedTime)` on the full time series → `FullDataModel`.
5. Extract parameters for both models.

**Output tibble — one row per sample:**

| Column | Notes |
|---|---|
| `SampleId`, `Group`, `DisplayLabel` | identifiers |
| `LinearRangeStart`, `LinearRangeStop` | 1-based row indices into the averaged data |
| `LinearSectionScore` | composite score used to select the window |
| `LinearDataSlope` | primary outcome — kinase activity proxy |
| `LinearDataRSquared` | adjusted R² of linear-range model |
| `LinearDataFValue` | F-statistic |
| `LinearDataConfintLower`, `LinearDataConfintUpper` | 95% CI on slope |
| `FullDataSlope`, `FullDataRSquared`, `FullDataFValue` | same for full-series model |
| `FullDataConfintLower`, `FullDataConfintUpper` | |

The `.RDS` results object retains nested model objects; the CSV export strips them.

---

## Linear range detection

### Scoring function (must match on both R and Rust sides)

The window score is **not** raw R². It is a composite that penalises curvature:

```
score = r² / (1 + curvatureNorm)

curvatureNorm = quantile(|diff²(signal)|, 0.90) / (range(signal) + ε)
```

where `diff²` is the second-order finite difference (`diff(y, differences = 2)`)
and `ε = 1e-8` guards against zero-range windows. Windows with `sd(times) < 1e-8`
(degenerate time axis) are skipped.

The brute-force search iterates all `(start, end)` pairs where the window spans
at least `minPoints` observations (default `10`, matching the original R script).
The pair with the highest score is returned as **1-based** indices.

### `findLinearRange()` dispatcher — `R/linear_range.R`

```r
findLinearRange(signal, times, minPoints = 10L)
# → list(LinearRangeStart, LinearRangeStop, LinearSectionScore)
```

- All input validation (`stopifnot`: length match, numeric, finite) lives here.
- Dispatches to `findLinearRangeRust()` if `isRustAvailable()`, else to
  `findLinearRangeR()`.
- Both backends must produce numerically identical results. This is verified in
  `tests/testthat/test-linear_range.R` against a suite of fixed inputs.
- Do not change `minPoints` default without updating the corresponding test snapshot.

### Rust implementation — `src/rust/src/lib.rs`

Exported function signature:

```rust
#[extendr]
fn findLinearRangeRust(signal: &[f64], times: &[f64], minPoints: i32) -> Vec<f64>
// Returns [start_1based, end_1based, score] — Vec<f64> of length 3
```

Return `Vec<f64>` of length 3, not a named list, to keep the FFI boundary simple.
The R dispatcher unpacks it into the named list. Rust works in 0-based indices
internally and converts to 1-based before returning. The curvature scoring must
be numerically equivalent to the R fallback — compare on the integration test
fixtures if in doubt.

---

## Shiny application

### Entry point — `aqlyzerApp()` — `R/app.R`

The Shiny app is a Bioconductor-standard exported function that returns a
`shiny::shinyApp` object. It is never run directly; the caller decides how to
launch it.

```r
#' Launch the aqlyzer Shiny application
#'
#' Returns a \code{shiny::shinyApp} object. Launch with
#' \code{shiny::runApp(aqlyzerApp())} or pass to any Shiny-compatible host.
#'
#' @export
aqlyzerApp <- function() {
    shiny::shinyApp(
        ui     = aqlyzerUi(),        # internal
        server = aqlyzerServer       # internal
    )
}
```

`aqlyzerUi()` and `aqlyzerServer` are **not exported**. They are defined in the
same file and documented only via internal roxygen (`@noRd`). This keeps the
public API surface minimal while still allowing `testServer()` to reach the server
function directly in tests.

To run from source:

```r
devtools::load_all()
shiny::runApp(aqlyzerApp())
```

### Module structure

All module code lives in `R/mod_*.R`, not in `inst/`. This is deliberate:
modules are package functions, not files sourced at runtime. They are importable,
documentable, and testable with `shiny::testServer()`.

Each module exposes two functions following the standard Shiny module convention:
- `*Ui(id)` — returns a `tagList`; may be called `*Ui` (not exported)
- `*Server(id, ...)` — the server function; may be called `*Server` (not exported)

#### `mod_upload.R` — `uploadUi()` / `uploadServer()`

- Accepts instrument XLSX via `fileInput`.
- On upload: reads column names, infers well addresses present, previews time range
  (first/last `ElapsedTime`).
- Returns a reactive holding the parsed raw data tibble and the file path (for
  hashing in provenance).
- Does **not** call `preprocessRun()` — that requires a validated layout.

#### `mod_plate_editor.R` — `plateEditorUi()` / `plateEditorServer()`

- Renders an interactive `rhandsontable` 8×12 grid (rows A–H, cols 1–12).
- Each cell shows `sampleId`; columns for `sampleType`, `group`, `inhibited`,
  `heatInactivated`, `displayLabel` are editable in a sidebar table or inline.
- Accepts upload of a pre-filled CSV layout (must match `plateLayoutDf` column
  names exactly) as an alternative to manual entry.
- On submission: calls `validateLayout()` against the uploaded data's well set.
  Structural errors render as inline messages; the layout is not emitted until all
  errors are resolved.
- Returns a reactive holding the validated `plateLayoutDf`.

#### `mod_results.R` — `resultsUi()` / `resultsServer()`

- Receives the raw data reactive and the layout reactive from upstream modules.
- On Run: executes the pipeline in sequence:
  `preprocessRun()` → `checkLayoutPlausibility()` → `processSignals()` → `fitModels()`
- Plausibility warnings from `checkLayoutPlausibility()` are shown on a well-grid
  overlay **before** results are displayed.
- Results tab: parameter table with `DisplayLabel` as row identifier, QC plots
  (signal traces by `sampleType`, slope distributions by `group`).
- Downloads: params CSV, averaged data CSV, full `.RDS` results object (includes
  provenance hashes).

---

## Testing

Everything should be independently unit-testable and integration-testable. The
boundary between unit and integration is whether example files from `inst/extdata/`
are used.

### Unit tests — `tests/testthat/test-*.R`

Unit tests use only synthetic, inline data — no file I/O, no `inst/extdata/`. Each
pipeline function is tested in isolation.

**`test-linear_range.R`** (exists):
- Parity: `findLinearRangeR()` and `findLinearRangeRust()` must return identical
  indices and score on every fixture.
- Edge cases: minimum-length input, flat signal, monotone signal, signal with
  clear curvature inflection.
- 1-based index invariant: returned start and end are ≥ 1 and ≤ length(signal).

**`test-plate_layout.R`** (to be added):
- `validateLayout()` returns the correct error keys for each structural violation.
- A valid layout passes with no errors.
- `checkLayoutPlausibility()` flags elevated blanks, flat samples, divergent
  replicates, and passes on clean data.

**`test-preprocess.R`** (to be added):
- Output tibble has the expected columns and types.
- `ElapsedTime` conversion is correct (Excel serial days → seconds).
- Wells in output match the layout exactly.
- Missing wells in data vs layout raises a structured error.

**`test-signals.R`** (to be added):
- Zeroing sets t=0 signal to zero for all wells.
- Blank subtraction removes the correct mean blank value at each time point.
- Replicate averaging collapses duplicate `sampleId` rows correctly.
- Wells with `sampleType == "blank"` are excluded from the averaged output.

**`test-models.R`** (to be added):
- Output has one row per unique `sampleId`.
- `LinearRangeStart` ≤ `LinearRangeStop`; both 1-based, within data bounds.
- `LinearDataSlope` and `FullDataSlope` are finite numerics.
- Confidence interval columns are ordered (lower < upper).

**`test-app.R`** (to be added — Shiny module tests):
- Use `shiny::testServer()` for each module server function.
- `uploadServer`: verify that uploading the example XLSX produces a non-null raw
  data reactive with the expected column names.
- `plateEditorServer`: verify that a valid layout CSV produces a `plateLayoutDf`
  reactive passing `validateLayout()` with no errors; verify that a layout with
  missing wells produces the correct error keys.
- `resultsServer`: given a pre-built raw data reactive and valid layout reactive,
  verify that clicking Run produces a non-null results reactive with the expected
  structure.

### Integration tests — `tests/testthat/test-integration.R`

Uses `system.file("extdata", ..., package = "aqlyzer")` to load the bundled
example run XLSX and example layout. Tests the full pipeline from file to results
object and checks:
- Results structure matches the expected schema (column names, types).
- Provenance hashes are present and non-empty.
- `layoutHash` changes if the layout is modified.
- `LinearDataSlope` values for `sampleType == "aqPeptide"` wells are positive and
  within a plausible range for the example data.
- Serialise with `saveRDS()` and reload; confirm round-trip fidelity.

### App end-to-end tests (optional, `tests/testthat/test-app-e2e.R`)

Use `shinytest2` for browser-level testing. These are slower and require a
display; mark with `skip_on_ci()` unless CI has a display. Cover:
- Upload → plate editor → run → download cycle with example data.
- Structural validation errors appear in the UI when a bad layout is submitted.
- Plausibility warnings appear on the well grid before results.

---

## Common commands

```r
# After any Rust or roxygen change:
rextendr::document()        # compile Rust + regenerate wrappers + run roxygen2

# Interactive development:
devtools::load_all()        # compile Rust + load package
shiny::runApp(aqlyzerApp()) # launch the app from source

# Testing:
devtools::test()                                              # full suite
testthat::test_file("tests/testthat/test-linear_range.R")    # single file
testthat::test_file("tests/testthat/test-integration.R")     # integration only

# Checks:
devtools::check()           # R CMD check
BiocCheck::BiocCheck(".")   # Bioconductor-specific checks
```

CI runs Bioconductor checks via `.github/workflows/check-bioc.yml`.

---

## Conventions (enforced — match them or pre-commit hooks will fail)

- **camelCase** for all object and function names — enforced by `object_name_linter`
  in `.lintr`. Bioconductor convention, not stylistic preference. Applies to both
  R and Rust: `findLinearRangeRust`, `minPoints`, `plateLayoutDf`, `sampleType`.
- **4-space indentation**, 120-character line limit (styler tidyverse style,
  `indent_by = 4`).
- **Conventional Commits** required (`commit-msg` hook). Allowed types:
  `build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test, bump`.
- No `browser()` / `debug()` statements in committed code.
- Do not commit `.Rhistory`, `.RData`, or `.Rds` files.
- Do not manually edit `R/extendr-wrappers.R` or `NAMESPACE`.

---

## Tooling: hk + mise

Git hooks are driven by **hk** (`hk.pkl`), with all custom logic as **mise** tasks
in `.mise/tasks/` invoked via `mise run <task>`. `mise.toml` pins `hk`,
`typos-cli`, and `jq`.

The pre-commit chain **auto-bumps the package version** (`bump-version` task,
touching `DESCRIPTION`) and regenerates `codemeta`; the post-commit hook
auto-creates a version tag. Do **not** manually edit the version field in
`DESCRIPTION`.
