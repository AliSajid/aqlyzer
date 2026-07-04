#' Find the linear range of a fluorescence kinetics curve
#'
#' Dispatches to a compiled Rust implementation when available,
#' falling back to a pure R implementation otherwise.
#'
#' @param rfu Numeric vector of RFU values, time-ordered.
#' @param minPoints Minimum window size (default 5).
#' @return Integer vector c(start, end), 1-based indices into RFU.
#' @export
findLinearRange <- function(rfu, minPoints = 5L) {
    stopifnot(is.numeric(rfu), length(rfu) >= minPoints)

    if (isRustAvailable()) {
        findLinearRangeRust(rfu, minPoints)
    } else {
        findLinearRangeR(rfu, minPoints)
    }
}

# Pure R fallback — same algorithm, slower
findLinearRangeR <- function(rfu, minPoints) {
    n <- length(rfu)
    bestR2 <- -Inf
    best <- c(1L, n)

    for (start in seq_len(n)) {
        for (end in (start + minPoints - 1L):n) {
            if (end > n) break
            sl <- rfu[start:end]
            x <- seq_along(sl)
            r2 <- cor(x, sl)^2L
            if (!is.na(r2) && r2 > bestR2) {
                bestR2 <- r2
                best <- c(start, end)
            }
        }
    }
    best
}

isRustAvailable <- function() {
    exists("findLinearRangeRust", mode = "function")
}
