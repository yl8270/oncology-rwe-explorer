weighted_mean <- function(x, w) sum(x * w) / sum(w)
weighted_sd <- function(x, w) sqrt(weighted_mean((x - weighted_mean(x, w))^2, w))

standardized_difference <- function(x, a, w = rep(1, length(x))) {
  ok <- is.finite(x)
  x <- x[ok]; a <- a[ok]; w <- w[ok]
  if (!all(0:1 %in% a)) return(NA_real_)
  # Fixed, unweighted population second-moment denominator for both comparisons.
  denominator <- sqrt((weighted_sd(x[a == 0], rep(1, sum(a == 0)))^2 +
                       weighted_sd(x[a == 1], rep(1, sum(a == 1)))^2) / 2)
  difference <- weighted_mean(x[a == 1], w[a == 1]) - weighted_mean(x[a == 0], w[a == 0])
  if (denominator < 1e-12) return(if (abs(difference) < 1e-12) 0 else sign(difference) * Inf)
  difference / denominator
}

balance_table <- function(d) {
  rows <- list()
  add <- function(name, x) {
    rows[[length(rows) + 1L]] <<- data.frame(covariate = name,
      unweighted_smd = standardized_difference(x, d$treatment),
      weighted_smd = standardized_difference(x, d$treatment, d$weight))
  }
  for (v in baseline_variables("expanded")) {
    x <- d[[v]]
    if (is.numeric(x)) add(v, x) else {
      for (lev in levels(droplevels(x))) add(paste(v, lev, sep = ": "), as.numeric(x == lev))
    }
    if (anyNA(x)) add(paste(v, "missing", sep = ": "), as.numeric(is.na(x)))
  }
  # Verify nonlinear age features represented in the PS as well as raw covariates.
  age_basis <- splines::ns(d$age, df = 3)
  for (j in seq_len(ncol(age_basis))) add(paste0("age spline basis ", j), age_basis[, j])
  out <- do.call(rbind, rows)
  out$abs_unweighted <- abs(out$unweighted_smd); out$abs_weighted <- abs(out$weighted_smd)
  out
}

table_one <- function(d) {
  rows <- list()
  add <- function(v, lev, z) {
    rows[[length(rows) + 1L]] <<- data.frame(variable = v, level = lev,
      control_observed = z[1], treated_observed = z[2],
      control_weighted = z[3], treated_weighted = z[4])
  }
  for (v in baseline_variables("expanded")) {
    x <- d[[v]]
    if (is.numeric(x)) {
      z <- character(4)
      for (a in 0:1) {
        ok <- d$treatment == a & !is.na(x)
        z[a + 1] <- sprintf("%.1f (%.1f)", mean(x[ok]), sd(x[ok]))
        z[a + 3] <- sprintf("%.1f (%.1f)", weighted_mean(x[ok], d$weight[ok]), weighted_sd(x[ok], d$weight[ok]))
      }
      add(v, "Mean (SD)", z)
    } else for (lev in levels(droplevels(x))) {
      z <- character(4)
      for (a in 0:1) {
        ok <- d$treatment == a & !is.na(x)
        count <- sum(x[ok] == lev)
        z[a + 1] <- sprintf("%d (%.1f%%)", count, 100 * count / sum(ok))
        z[a + 3] <- sprintf("%.1f%%", 100 * weighted_mean(as.numeric(x[ok] == lev), d$weight[ok]))
      }
      add(v, lev, z)
    }
    z <- character(4)
    for (a in 0:1) {
      ok <- d$treatment == a
      z[a + 1] <- sprintf("%d (%.1f%%)", sum(is.na(x[ok])), 100 * mean(is.na(x[ok])))
      z[a + 3] <- sprintf("%.1f%%", 100 * weighted_mean(as.numeric(is.na(x[ok])), d$weight[ok]))
    }
    add(v, "Missing / all in arm", z)
  }
  do.call(rbind, rows)
}

missingness_table <- function(d) {
  do.call(rbind, lapply(baseline_variables("expanded"), function(v)
    do.call(rbind, lapply(0:1, function(a) {
      idx <- d$treatment == a
      data.frame(variable = v, treatment = levels(d$treatment_label)[a + 1],
                 n = sum(idx), missing_n = sum(is.na(d[[v]][idx])), missing_pct = 100 * mean(is.na(d[[v]][idx])))
    }))))
}
