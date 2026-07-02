#' Find the linear range of a fluorescence kinetics curve
#'
#' Dispatches to a compiled Rust implementation when available,
#' falling back to a pure R implementation otherwise.
#'
#' @param rfu Numeric vector of RFU values, time-ordered.
#' @param min_points Minimum window size (default 5).
#' @return Integer vector c(start, end), 1-based indices into rfu.
#' @export
find_linear_range <- function(rfu, min_points = 5L) {
    stopifnot(is.numeric(rfu), length(rfu) >= min_points)

    if (is_rust_available()) {
        find_linear_range_rust(rfu, min_points)
    } else {
        find_linear_range_r(rfu, min_points)
    }
}

# Pure R fallback — same algorithm, slower
find_linear_range_r <- function(rfu, min_points) {
    n <- length(rfu)
    best_r2 <- -Inf
    best <- c(1L, n)

    for (start in seq_len(n)) {
        for (end in (start + min_points - 1L):n) {
            if (end > n) break
            sl <- rfu[start:end]
            x <- seq_along(sl)
            r2 <- cor(x, sl)^2
            if (!is.na(r2) && r2 > best_r2) {
                best_r2 <- r2
                best <- c(start, end)
            }
        }
    }
    best
}

is_rust_available <- function() {
    exists("find_linear_range_rust", mode = "function")
}
