# Test suite for findLinearRange() / findLinearRangeR() / findLinearRangeRust()

# Fixed fixtures shared by the format and parity tests below. Chosen to
# cover the edge cases CLAUDE.md calls out: minimum-length input, a flat
# signal, a monotone signal, and a signal with a clear curvature inflection.
linearRangeFixtures <- list(
    minimal  = list(rfu = as.numeric(1L:5L), minPoints = 5L),
    flat     = list(rfu = rep(50.0, 20L), minPoints = 5L),
    monotone = list(rfu = as.numeric(1L:60L), minPoints = 10L),
    plateau  = list(rfu = c(seq(100.0, 220.0, length.out = 60L), rep(220.0, 40L)), minPoints = 10L)
)

test_that("findLinearRangeR returns valid 1-based indices for every fixture", {
    for (fixture in linearRangeFixtures) {
        result <- findLinearRangeR(fixture$rfu, minPoints = fixture$minPoints)

        expect_type(result, "integer")
        expect_length(result, 2L)
        expect_gte(result[1L], 1L)
        expect_lte(result[1L], length(fixture$rfu))
        expect_gte(result[2L], 1L)
        expect_lte(result[2L], length(fixture$rfu))
        expect_gte(result[2L], result[1L])
        expect_gte(result[2L] - result[1L] + 1L, fixture$minPoints)
    }
})

test_that("findLinearRangeRust returns valid 1-based indices for every fixture", {
    skip_if_not(isRustAvailable())

    for (fixture in linearRangeFixtures) {
        result <- findLinearRangeRust(fixture$rfu, minPoints = fixture$minPoints)

        expect_length(result, 2L)
        expect_gte(result[1L], 1L)
        expect_lte(result[1L], length(fixture$rfu))
        expect_gte(result[2L], 1L)
        expect_lte(result[2L], length(fixture$rfu))
        expect_gte(result[2L], result[1L])
        expect_gte(result[2L] - result[1L] + 1L, fixture$minPoints)
    }
})

test_that("findLinearRangeR and findLinearRangeRust agree on every fixture", {
    skip_if_not(isRustAvailable())

    for (name in names(linearRangeFixtures)) {
        fixture <- linearRangeFixtures[[name]]
        rResult <- findLinearRangeR(fixture$rfu, minPoints = fixture$minPoints)
        rustResult <- as.integer(findLinearRangeRust(fixture$rfu, minPoints = fixture$minPoints))

        expect_identical(rResult, rustResult, info = paste("fixture:", name))
    }
})

test_that("findLinearRangeR and findLinearRangeRust agree on randomized realistic curves", {
    skip_if_not(isRustAvailable())

    set.seed(42L)
    for (trial in 1L:30L) {
        n <- sample(15L:120L, 1L)
        minPoints <- sample(5L:15L, 1L)
        slope <- runif(1L, 0.1, 3.0)
        plateauFrom <- round(n * runif(1L, 0.4, 0.8))
        rfu <- c(
            100.0 + slope * seq_len(plateauFrom),
            rep(100.0 + slope * plateauFrom, n - plateauFrom)
        ) + rnorm(n, sd = runif(1L, 1.0, 10.0))

        rResult <- findLinearRangeR(rfu, minPoints = minPoints)
        rustResult <- as.integer(findLinearRangeRust(rfu, minPoints = minPoints))

        expect_identical(rResult, rustResult, info = paste("trial:", trial))
    }
})

test_that("findLinearRange dispatches to the Rust backend when available", {
    skip_if_not(isRustAvailable())

    rfu <- linearRangeFixtures$plateau$rfu
    expect_identical(
        findLinearRange(rfu, minPoints = 10L),
        findLinearRangeRust(rfu, minPoints = 10L)
    )
})

test_that("findLinearRange falls back to the R backend when Rust is unavailable", {
    testthat::local_mocked_bindings(isRustAvailable = function() FALSE)

    rfu <- linearRangeFixtures$plateau$rfu
    expect_identical(
        findLinearRange(rfu, minPoints = 10L),
        findLinearRangeR(rfu, minPoints = 10L)
    )
})

test_that("findLinearRange validates its inputs", {
    expect_error(findLinearRange(1L:4L, minPoints = 5L), "length.rfu. >= minPoints")
    expect_error(findLinearRange(numeric(0L), minPoints = 5L), "length.rfu. >= minPoints")
    expect_error(findLinearRange(c("a", "b", "c", "d", "e"), minPoints = 5L), "is.numeric.rfu.")

    expect_silent(findLinearRange(as.numeric(1L:5L), minPoints = 5L))
})

test_that("findLinearRangeRust is faster than findLinearRangeR at realistic dataset sizes", {
    skip_if_not(isRustAvailable())

    set.seed(111L)
    # Real assay data tops out around 120 points (CLAUDE.md); this dataset is
    # deliberately larger so the compiled-vs-interpreted speed gap is
    # unambiguous without letting the brute-force search run for minutes.
    signal <- rnorm(500L, mean = 100.0, sd = 5.0)

    timeR <- min(replicate(3L, system.time(findLinearRangeR(signal, minPoints = 10L))[["elapsed"]]))
    timeRust <- min(replicate(3L, system.time(findLinearRangeRust(signal, minPoints = 10L))[["elapsed"]]))

    expect_lt(timeRust, timeR)
})
