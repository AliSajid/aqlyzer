#' Find the linear range of a fluorescence kinetics curve
#'
#' Dispatches to a compiled Rust implementation when available,
#' falling back to a pure R implementation otherwise.
#'
#' @param rfu Numeric vector of RFU values, time-ordered.
#' @param minPoints Minimum window size (default 5).
#' @return Integer vector c(start, end), 1-based indices into RFU.
#' @export
#'
#' @examples
#' # Synthetic fluorescence curve: linear rise followed by a plateau
#' set.seed(123)
#' time <- 1:100
#' rfu <- c(100 + 2 * 1:60, rep(220, 40)) + rnorm(100, sd = 5)
#'
#' result <- findLinearRange(rfu, minPoints = 10L)
#' plot(time, rfu, type = "l", main = "Fluorescence Kinetics")
#' abline(v = result[1], col = "red", lty = 2)
#' abline(v = result[2], col = "red", lty = 2)
#' legend("bottomright", legend = "Detected linear range", col = "red", lty = 2)
findLinearRange <- function(rfu, minPoints = 5L) {
    stopifnot(is.numeric(rfu), length(rfu) >= minPoints)

    if (isRustAvailable()) {
        findLinearRangeRust(rfu, minPoints)
    } else {
        findLinearRangeR(rfu, minPoints)
    }
}

#' Pure R fallback — same algorithm, slower
#'
#' Brute-force search over all `(start, end)` window pairs, same algorithm
#' as \code{findLinearRangeRust()}. Used by \code{findLinearRange()} when
#' the compiled Rust backend is unavailable; not intended to be called
#' directly outside of backend-parity tests.
#'
#' The window R² is computed via the same sum-of-squares formula as the
#' Rust backend (rather than \code{stats::cor()}) so both backends do
#' numerically identical arithmetic. This matters because smooth curves
#' produce many windows with near-identical R²; a different formula's
#' rounding can flip which window wins the search.
#'
#' @param rfu Numeric vector of RFU values, time-ordered.
#' @param minPoints Minimum window size.
#' @return Integer vector c(start, end), 1-based indices into RFU.
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Not exported — for illustration only; use findLinearRange() instead.
#' rfu <- c(
#'     100, 102, 101, 103, 105, 107, 109, 111, 113, 115, 117, 119,
#'     118, 116, 114, 112, 110, 108, 106, 104
#' )
#' findLinearRangeR(rfu, minPoints = 3L)
#' }
findLinearRangeR <- function(rfu, minPoints) {
    n <- length(rfu)
    bestR2 <- -Inf
    best <- c(1L, n)

    for (start in seq_len(n)) {
        for (end in (start + minPoints - 1L):n) {
            if (end > n) break
            r2 <- windowR2(rfu, start, end)
            if (r2 > bestR2) {
                bestR2 <- r2
                best <- c(start, end)
            }
        }
    }
    best
}

#' Window R², computed identically to the Rust backend
#'
#' @param rfu Numeric vector of RFU values, time-ordered.
#' @param start 1-based start index of the window.
#' @param end 1-based end index of the window.
#' @return R² of `rfu[start:end]` against its 0-based position index, or
#'   `-Inf` if the window has zero variance in either axis.
#' @keywords internal
windowR2 <- function(rfu, start, end) {
    slice <- rfu[start:end]
    n <- length(slice)
    xMean <- (n - 1L) / 2L
    yMean <- sum(slice) / n

    dx <- seq_len(n) - 1L - xMean
    dy <- slice - yMean

    ssXy <- sum(dx * dy)
    ssXx <- sum(dx * dx)
    ssYy <- sum(dy * dy)

    if (ssXx == 0L || ssYy == 0L) {
        return(-Inf)
    }
    (ssXy * ssXy) / (ssXx * ssYy)
}

#' Checks for the availability of the Rust function
#'
#' @return Boolean depending on the presence of the Rust function
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Not exported — for illustration only.
#' isRustAvailable()
#' }
isRustAvailable <- function() {
    exists("findLinearRangeRust", mode = "function")
}
