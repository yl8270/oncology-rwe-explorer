effective_n <- function(w) sum(w)^2 / sum(w^2)

active_covariates <- function(d, spec) {
  vars <- baseline_variables(spec)
  vars[vapply(d[vars], function(x) length(unique(x[!is.na(x)])) > 1, logical(1))]
}

covariate_terms <- function(vars) {
  ifelse(vars == "age", "splines::ns(age, df = 3)", vars)
}

prepare_model_sample <- function(d, spec, check = TRUE) {
  vars <- baseline_variables(spec)
  needed <- c(vars, "facility_id")
  complete <- complete.cases(d[needed]) & nzchar(d$facility_id)
  for (v in vars[vapply(d[vars], is.numeric, logical(1))]) complete <- complete & is.finite(d[[v]])
  retention <- do.call(rbind, lapply(0:1, function(a) {
    idx <- d$treatment == a
    data.frame(treatment = levels(d$treatment_label)[a + 1], eligible_n = sum(idx),
      analysis_n = sum(idx & complete), excluded_missing_n = sum(idx & !complete),
      retention_pct = 100 * mean(complete[idx]))
  }))
  out <- droplevels(d[complete, , drop = FALSE])
  if (check && (nrow(out) < 50 || any(table(factor(out$treatment, levels = 0:1)) < 20)))
    stop("Complete-case sample has fewer than 20 individuals in an arm.")
  if (check && length(unique(out$facility_id)) < 10) stop("At least ten fictional facilities are required.")
  list(data = out, retention = retention)
}

fit_weights <- function(d, cfg) {
  vars <- active_covariates(d, cfg$ps_spec)
  formula <- reformulate(covariate_terms(vars), response = "treatment")
  warnings <- character()
  fit <- withCallingHandlers(glm(formula, data = d, family = binomial()), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  })
  ps <- as.numeric(fitted(fit))
  if (!fit$converged || anyNA(coef(fit)) || any(!is.finite(ps)) || any(ps < 1e-8 | ps > 1 - 1e-8) || length(warnings))
    stop("PS model separation, rank deficiency or convergence failure. Reduce overlap stress or increase sample size.")
  p <- mean(d$treatment)
  d$ps <- ps
  d$iptw <- ifelse(d$treatment == 1, p / ps, (1 - p) / (1 - ps))
  d$overlap <- ifelse(d$treatment == 1, 1 - ps, ps)
  d$weight <- switch(cfg$method, unweighted = rep(1, nrow(d)), iptw = d$iptw, overlap = d$overlap)
  cuts <- c(NA_real_, NA_real_)
  if (cfg$winsorize) {
    cuts <- as.numeric(quantile(d$weight, c(.01, .99)))
    d$weight <- pmax(cuts[1], pmin(cuts[2], d$weight))
  }
  if (any(!is.finite(d$weight) | d$weight <= 0)) stop("Invalid analysis weights.")
  diagnostics <- do.call(rbind, lapply(0:1, function(a) {
    z <- d[d$treatment == a, ]; w <- z$weight
    data.frame(treatment = levels(d$treatment_label)[a + 1], n = nrow(z), events = sum(z$event),
      ess = effective_n(w), weight_sum = sum(w), weight_min = min(w), weight_median = median(w),
      weight_p99 = as.numeric(quantile(w,.99)), weight_max = max(w),
      ps_min = min(z$ps), ps_max = max(z$ps), extreme_ps_pct = 100 * mean(z$ps < .05 | z$ps > .95))
  }))
  list(data = d, fit = fit, variables = vars, formula = deparse(formula), diagnostics = diagnostics,
       winsor_cutoffs = cuts)
}
