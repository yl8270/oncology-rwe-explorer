fit_km <- function(d, weighted = TRUE) {
  w <- if (weighted) d$weight else rep(1, nrow(d))
  survival::survfit(survival::Surv(time_months, event) ~ treatment_label, data = d,
                    weights = w, id = d$synthetic_id, robust = TRUE, conf.int = FALSE)
}

km_frame <- function(fit) {
  group <- rep(names(fit$strata), fit$strata)
  out <- data.frame(time = fit$time, survival = fit$surv,
                    arm = sub("^treatment_label=", "", group))
  initial <- data.frame(time = 0, survival = 1, arm = unique(out$arm))
  rbind(initial, out)
}

survival_at <- function(d, a, horizon, weighted = TRUE) {
  z <- d[d$treatment == a, ]
  if (!nrow(z) || horizon > max(z$time_months)) return(NA_real_)
  w <- if (weighted) z$weight else rep(1, nrow(z))
  f <- survival::survfit(survival::Surv(time_months, event) ~ 1, data = z, weights = w, conf.int = FALSE)
  idx <- which(f$time <= horizon)
  if (!length(idx)) 1 else as.numeric(f$surv[max(idx)])
}

risk_table <- function(d, times) {
  do.call(rbind, lapply(0:1, function(a) do.call(rbind, lapply(times, function(t) {
    z <- d[d$treatment == a & d$time_months >= t, ]
    data.frame(arm = levels(d$treatment_label)[a + 1], month_after_landmark = t,
      observed_at_risk = nrow(z), weighted_risk_mass = sum(z$weight),
      risk_set_ess = if (nrow(z)) effective_n(z$weight) else 0)
  }))))
}

fixed_time_survival <- function(d, horizon) {
  support <- risk_table(d, horizon)
  supported <- all(support$observed_at_risk >= 10 & support$risk_set_ess >= 5)
  est <- if (supported) c(survival_at(d, 0, horizon), survival_at(d, 1, horizon)) else c(NA_real_, NA_real_)
  list(table = data.frame(quantity = c("Control survival", "Treated survival", "Treated minus control"),
        estimate = c(est, est[2] - est[1]), lower_95 = NA_real_, upper_95 = NA_real_,
        horizon_months_after_landmark = horizon), support = support, supported = supported)
}

bootstrap_fixed_time <- function(d, cfg, point, progress = NULL) {
  B <- cfg$bootstrap_reps
  no_failures <- data.frame(replicate = integer(), reason = character())
  if (B == 0 || !point$supported) return(list(table = point$table,
    audit = data.frame(requested = B, attempted = 0, successful = 0, failed = 0, status = if (B == 0) "Not requested" else "Unsupported horizon"),
    draws = data.frame(), failures = no_failures))
  with_local_seed(cfg$seed + 7001L, {
    facilities <- unique(d$facility_id)
    pieces <- split(d, d$facility_id)
    draws <- matrix(NA_real_, nrow = B, ncol = 3)
    failures <- no_failures
    for (b in seq_len(B)) {
      sampled <- sample(facilities, length(facilities), replace = TRUE)
      z <- do.call(rbind, lapply(seq_along(sampled), function(j) {
        x <- pieces[[sampled[j]]]
        x$facility_id <- paste0("BOOT-", j)
        x$synthetic_id <- paste0(x$synthetic_id, "-", j)
        x
      }))
      ans <- tryCatch({
        fit <- fit_weights(droplevels(z), cfg)
        support <- fixed_time_survival(fit$data, cfg$horizon_months)
        if (!support$supported) stop("Unsupported bootstrap horizon")
        support$table$estimate
      }, error = function(e) {
        failures <<- rbind(failures, data.frame(replicate = b, reason = conditionMessage(e)))
        rep(NA_real_, 3)
      })
      draws[b, ] <- ans
      if (is.function(progress)) progress(b, B)
    }
    ok <- complete.cases(draws)
    tab <- point$table
    minimum <- max(10, ceiling(.8 * B))
    if (sum(ok) >= minimum) {
      limits <- apply(draws[ok, , drop = FALSE], 2, quantile, probs = c(.025, .975))
      tab$lower_95 <- limits[1, ]; tab$upper_95 <- limits[2, ]
    }
    list(table = tab, audit = data.frame(requested = B, attempted = B, successful = sum(ok), failed = sum(!ok),
      status = if (sum(ok) >= minimum) "Percentile CI; PS refit in every facility resample" else "CI withheld: too few successful resamples"),
      draws = data.frame(control = draws[,1], treated = draws[,2], difference = draws[,3]), failures = failures)
  })
}

checked_cox <- function(formula, d, weighted = TRUE) {
  warnings <- character()
  d$.analysis_weight <- if (weighted) d$weight else rep(1, nrow(d))
  fit <- withCallingHandlers(survival::coxph(formula, data = d,
    weights = .analysis_weight,
    cluster = facility_id, robust = TRUE, ties = "efron", x = TRUE, model = TRUE,
    singular.ok = FALSE), warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
    })
  if (length(warnings) || any(!is.finite(coef(fit))) || any(!is.finite(vcov(fit))))
    stop(paste("Cox convergence/estimability failure:", paste(warnings, collapse = "; ")))
  fit
}

cox_row <- function(fit, label, n, events, term = "treatment") {
  b <- coef(fit)[term]; se <- sqrt(vcov(fit)[term, term])
  data.frame(model = label, n = n, events = events, hr = exp(b),
    lower_95 = exp(b - qnorm(.975) * se), upper_95 = exp(b + qnorm(.975) * se),
    p_wald = 2 * pnorm(-abs(b / se)), variance = "Facility-cluster sandwich; conditional on fitted weights")
}

fit_cox_models <- function(d, cfg) {
  basic <- survival::Surv(time_months, event) ~ treatment
  conventional <- reformulate(c("treatment", covariate_terms(active_covariates(d, cfg$ps_spec))),
                                response = "survival::Surv(time_months, event)")
  models <- list(Unadjusted = checked_cox(basic, d, FALSE),
                 `Covariate-adjusted` = checked_cox(conventional, d, FALSE),
                 `Selected weighting` = checked_cox(basic, d, TRUE))
  tab <- do.call(rbind, lapply(names(models), function(nm) cox_row(models[[nm]], nm, nrow(d), sum(d$event))))
  # cox.zph is a Schoenfeld score diagnostic, not a clustered formal test.
  ph <- tryCatch(as.data.frame(survival::cox.zph(models[[3]], transform = "km")$table),
                 error = function(e) data.frame(chisq = NA_real_, df = NA_real_, p = NA_real_))
  ph$term <- rownames(ph); rownames(ph) <- NULL
  ph$interpretation <- "Exploratory Schoenfeld diagnostic; no cluster/PS-uncertainty calibration"
  lr <- survival::survdiff(basic, data = d)
  list(table = tab, fits = models, ph = ph, unweighted_logrank_p = pchisq(lr$chisq, 1, lower.tail = FALSE))
}

subgroup_analysis <- function(d, variable) {
  d$sg <- droplevels(factor(d[[variable]]))
  groups <- levels(d$sg)
  counts <- do.call(rbind, lapply(groups, function(g) do.call(rbind, lapply(0:1, function(a) {
    z <- d[d$sg == g & d$treatment == a, ]
    data.frame(subgroup = g, arm = a, n = nrow(z), events = sum(z$event),
               ess = if (nrow(z)) effective_n(z$weight) else 0)
  }))))
  empty <- data.frame(subgroup = groups, hr = NA_real_, lower_95 = NA_real_, upper_95 = NA_real_)
  if (length(groups) < 2 || any(counts$n < 20 | counts$events < 5 | counts$ess < 10))
    return(list(table = empty, counts = counts, interaction_p = NA_real_, status = "Suppressed: sparse subgroup arm or insufficient ESS"))
  tryCatch({
    fit <- checked_cox(survival::Surv(time_months, event) ~ treatment * sg, d)
    beta <- coef(fit); V <- vcov(fit)
    terms <- names(beta)[grepl("treatment:sg", names(beta), fixed = TRUE)]
    b <- beta[terms]; subV <- V[terms, terms, drop = FALSE]
    wald <- as.numeric(t(b) %*% solve(subV, b))
    tab <- do.call(rbind, lapply(seq_along(groups), function(j) {
      contrast <- setNames(rep(0, length(beta)), names(beta)); contrast["treatment"] <- 1
      if (j > 1) contrast[paste0("treatment:sg", groups[j])] <- 1
      b <- sum(contrast * beta); se <- sqrt(as.numeric(t(contrast) %*% V %*% contrast))
      z <- counts[counts$subgroup == groups[j], ]
      data.frame(subgroup = groups[j], n = sum(z$n), events = sum(z$events), hr = exp(b),
                 lower_95 = exp(b - qnorm(.975) * se), upper_95 = exp(b + qnorm(.975) * se))
    }))
    list(table = tab, counts = counts, interaction_p = pchisq(wald, length(terms), lower.tail = FALSE),
         status = "Exploratory pooled interaction; global weights retained; no multiplicity adjustment")
  }, error = function(e) list(table = empty, counts = counts, interaction_p = NA_real_, status = conditionMessage(e)))
}
