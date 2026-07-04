use extendr_api::prelude::*;

/// Find the linear range of a fluorescence curve by maximising
/// window R² over all valid start/end index pairs.
///
/// @param rfu  Numeric vector of RFU values (time-ordered).
/// @param min_points  Minimum number of points a window must span.
/// @return Integer vector of length 2: c(start_idx, end_idx), 1-based.
/// @export
#[extendr]
fn findLinearRangeRust(rfu: &[f64], minPoints: i32) -> Vec<i32> {
    let n = rfu.len();
    let minW = minPoints as usize;

    let mut bestR2 = f64::NEG_INFINITY;
    let mut best = (0usize, n - 1);

    for start in 0..n {
        for end in (start + minW - 1)..n {
            let r2 = windowR2(rfu, start, end);
            if r2 > bestR2 {
                bestR2 = r2;
                best = (start, end);
            }
        }
    }

    // Return 1-based indices for R
    vec![(best.0 + 1) as i32, (best.1 + 1) as i32]
}

fn windowR2(y: &[f64], start: usize, end: usize) -> f64 {
    let slice = &y[start..=end];
    let n = slice.len() as f64;
    let x_mean = (n - 1.0) / 2.0;
    let y_mean = slice.iter().sum::<f64>() / n;

    let (ss_xy, ss_xx, ss_yy) = slice.iter().enumerate().fold(
        (0.0_f64, 0.0_f64, 0.0_f64),
        |(xy, xx, yy), (i, &yi)| {
            let dx = i as f64 - x_mean;
            let dy = yi - y_mean;
            (xy + dx * dy, xx + dx * dx, yy + dy * dy)
        },
    );

    if ss_xx == 0.0 || ss_yy == 0.0 {
        return f64::NEG_INFINITY;
    }
    (ss_xy * ss_xy) / (ss_xx * ss_yy)  // R²
}

extendr_module! {
    mod aqlyzer;
    fn findLinearRangeRust;
}
