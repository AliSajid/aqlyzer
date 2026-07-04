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
#' # Generate synthetic fluorescence data with linear and plateau regions
#' set.seed(123)
#' time <- 1:100
#' rfu <- 100 + 0.5 * time + 20 * rnorm(100)  # Linear phase with noise
#' result <- findLinearRange(rfu, minPoints = 5)
#' plot(time, rfu, type = "l", main = "Fluorescence Kinetics")
#' abline(v = result[1], col = "red", lty = 2)
#' abline(v = result[2], col = "red", lty = 2)
#' legend("topright", legend = c("Linear Range", paste0("Start:", result[1])),
#'        col = c("red", "blue"), lty = c(2, 1))
#'
#' # Example with actual assay data
#' # data("fluorescence_data")
#' # result <- findLinearRange(fluorescence_data, minPoints = 10)
#' # start_point <- result[1]
#' # end_point <- result[2]
#' # linear_values <- fluorescence_data[start_point:end_point]
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
#' @examples
#' # Generate test data
#' rfu <- c(100, 102, 101, 103, 105, 107, 109, 111, 113, 115, 117, 119,
#'          118, 116, 114, 112, 110, 108, 106, 104)
#'
#' # Find linear range using pure R implementation
#' result <- findLinearRangeR(rfu, minPoints = 3)
#' # Returns start and end indices of the linear region
#' print(result)
#'
#' @importFrom stats cor
findLinearRangeR <- function(rfu, minPoints) {
    n <- length(rfu)
    bestR2 <- -Inf
    best <- c(1L, n)

    for (start in seq_len(n)) {
        for (end in (start + minPoints - 1L):n) {
            if (end > n) break
            sl <- rfu[start:end]
            x <- seq_along(sl)
            r2 <- stats::cor(x, sl)^2L
            if (!is.na(r2) && r2 > bestR2) {
                bestR2 <- r2
                best <- c(start, end)
            }
        }
    }
    best
}


#' Checks for the availability of the Rust function
#'
#' @returns Boolean depending on the presence of the Rust function
isRustAvailable <- function() {
    exists("findLinearRangeRust", mode = "function")
}
