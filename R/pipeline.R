run_analysis <- function(cfg = default_config(), progress = NULL) {
  notify_progress <- function(value, detail) if (is.function(progress)) progress(value, detail)
  validate_config(cfg)
  notify_progress(.05, "Generating independent synthetic records")
  raw <- generate_synthetic(cfg$n, cfg$seed, cfg$disease, cfg$scenario, cfg$missing_rate)
  cohort <- construct_cohort(raw, cfg$disease)
  sample <- prepare_model_sample(cohort$data, cfg$ps_spec)
  notify_progress(.2, "Validating the cohort and estimating propensity scores")
  weights <- fit_weights(sample$data, cfg)
  d <- weights$data
  balance <- balance_table(d)
  fixed <- fixed_time_survival(d, cfg$horizon_months)
  notify_progress(.4, "Estimating conditional survival")
  bootstrap <- bootstrap_fixed_time(d, cfg, fixed, progress = function(done, total)
    notify_progress(.4 + .4 * done / total, sprintf("Facility bootstrap: %d / %d resamples", done, total)))
  notify_progress(.85, "Fitting clustered Cox models and subgroup interactions")
  cox <- fit_cox_models(d, cfg)
  subgroup <- subgroup_analysis(d, cfg$subgroup)
  flow <- rbind(cohort$flow, data.frame(step = paste("Complete baseline cases:", cfg$ps_spec),
    n_before = nrow(cohort$data), n_excluded = nrow(cohort$data) - nrow(d), n_after = nrow(d)))
  comparison <- do.call(rbind, lapply(c("core", "expanded"), function(spec) {
    x <- prepare_model_sample(cohort$data, spec, check = FALSE)$retention
    x$specification <- spec; x
  }))
  alerts <- character()
  if (any(weights$diagnostics$extreme_ps_pct > 5))
    alerts <- c(alerts, "More than 5% of an arm has PS outside [0.05, 0.95]; inspect positivity and weight tails.")
  if (any(weights$diagnostics$ess < .5 * weights$diagnostics$n))
    alerts <- c(alerts, "Weighting reduces an arm's ESS below half its observed sample size.")
  if (any(balance$abs_weighted >= .1, na.rm = TRUE))
    alerts <- c(alerts, "Residual |SMD| ≥0.10 exists. Weighting does not by itself establish adequate control of confounding.")
  if (any(sample$retention$retention_pct < 90))
    alerts <- c(alerts, "Complete-case retention is below 90% in an arm; the target population differs from all eligible records.")
  if (!fixed$supported) alerts <- c(alerts, "Fixed-time estimates withheld: fewer than 10 observed at risk or risk-set ESS <5 in an arm.")
  if (any(cox$ph$p < .05, na.rm = TRUE))
    alerts <- c(alerts, "PH diagnostic flags possible time variation. Treat a constant HR as a summary, not a stable effect over time.")
  if (cfg$bootstrap_reps > 0 && cfg$bootstrap_reps < 200)
    alerts <- c(alerts, "Fewer than 200 bootstrap resamples: percentile intervals are a quick demonstration, not publication inference.")
  if (fixed$supported && cfg$bootstrap_reps > 0 && anyNA(bootstrap$table$lower_95))
    alerts <- c(alerts, "Bootstrap confidence intervals withheld: insufficient successful resamples. See failure reasons in the analysis bundle.")
  preset <- study_preset(cfg$disease)
  result <- list(config = cfg, preset = preset, raw = raw, cohort = cohort$data, data = d,
    flow = flow, pre_landmark = cohort$pre_landmark, retention = sample$retention,
    retention_comparison = comparison, missingness = missingness_table(cohort$data),
    table1 = table_one(d), balance = balance, weights = weights,
    km = km_frame(fit_km(d)), raw_km = km_frame(fit_km(d, FALSE)),
    risk = risk_table(d, sort(unique(c(0, if (cfg$horizon_months >= 6) seq(6, cfg$horizon_months, by = 6), cfg$horizon_months)))),
    fixed = bootstrap$table, support = fixed$support, bootstrap = bootstrap,
    cox = cox, subgroup = subgroup, alerts = alerts,
    qc = data.frame(check = c("Sequential cohort reconciliation", "Unique synthetic model IDs",
      "Positive post-landmark follow-up", "Finite positive selected weights", "Same N across Cox models"),
      passed = c(sum(flow$n_excluded) + nrow(d) == nrow(raw), !anyDuplicated(d$synthetic_id),
        all(d$time_months > 0), all(is.finite(d$weight) & d$weight > 0), all(cox$table$n == nrow(d)))))
  result$manifest <- list(project = "Oncology RWE Explorer", engine_version = "1.2.0",
    generated_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), config = cfg,
    data_provenance = attr(raw, "provenance"), estimand = estimand_label(cfg),
    landmark_days = preset$landmark_days, horizon_months_after_landmark = cfg$horizon_months,
    horizon_days_from_diagnosis = preset$landmark_days + cfg$horizon_months * 365.25 / 12,
    selected_ps_formula = weights$formula, winsor_cutoffs = weights$winsor_cutoffs,
    bootstrap_unit = "fictional facility", bootstrap_ps_refit = TRUE,
    bootstrap_audit = bootstrap$audit,
    denominators = list(generated = nrow(raw), eligible_landmark = nrow(cohort$data),
                        complete_case = nrow(d), events = sum(d$event), facilities = length(unique(d$facility_id))),
    software = list(R = as.character(getRversion()),
      packages = setNames(lapply(c("shiny", "survival", "ggplot2", "jsonlite"),
                                function(p) as.character(utils::packageVersion(p))), c("shiny", "survival", "ggplot2", "jsonlite"))))
  stopifnot(all(result$qc$passed))
  notify_progress(1, "Analysis complete; run configuration locked to these results")
  result
}

export_analysis <- function(result, directory, include_figures = FALSE) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  tables <- list(cohort_flow = result$flow, pre_landmark = result$pre_landmark,
    retention = result$retention_comparison, missingness = result$missingness, table1 = result$table1,
    balance = result$balance, weights = result$weights$diagnostics, risk = result$risk,
    fixed_time_survival = result$fixed, horizon_support = result$support,
    bootstrap_audit = result$bootstrap$audit, bootstrap_draws = result$bootstrap$draws,
    bootstrap_failures = result$bootstrap$failures,
    cox = result$cox$table, ph = result$cox$ph, subgroup = result$subgroup$table,
    subgroup_counts = result$subgroup$counts, qc = result$qc,
    km_selected = result$km, km_unweighted = result$raw_km)
  for (nm in names(tables)) utils::write.csv(tables[[nm]], file.path(directory, paste0(nm, ".csv")), row.names = FALSE)
  if (include_figures) {
    figures <- list(survival = plot_survival(result), balance = plot_balance(result),
      propensity_overlap = plot_ps(result), cox = plot_forest(result$cox$table))
    for (nm in names(figures)) ggplot2::ggsave(file.path(directory, paste0(nm, ".pdf")), figures[[nm]],
      width = 9, height = if (nm == "balance") 9 else 5.5, device = vector_pdf_device())
  }
  utils::write.csv(result$raw, file.path(directory, "synthetic_generated.csv"), row.names = FALSE)
  utils::write.csv(result$data, file.path(directory, "synthetic_analysis.csv"), row.names = FALSE)
  jsonlite::write_json(result$manifest, file.path(directory, "manifest.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")
  jsonlite::write_json(result$config, file.path(directory, "config.json"), auto_unbox = TRUE, pretty = TRUE)
  writeLines(c("SYNTHETIC EDUCATIONAL RESULTS — NO REAL PATIENTS", estimand_label(result$config),
    sprintf("%g months after day-%d landmark", result$config$horizon_months, result$preset$landmark_days),
    "Weighted Cox intervals condition on fitted weights; absolute survival CIs refit PS via facility bootstrap.",
    paste("Formal exploratory subgroup interaction p:", result$subgroup$interaction_p),
    result$subgroup$status, "Table 1: observed counts; weighted percentages, weighted population SD; nonmissing category denominators.",
    "Replay with: Rscript scripts/run_example.R path/to/config.json path/to/new_output", result$alerts),
    file.path(directory, "RESULT_NOTES.txt"))
  write_analysis_report(result, file.path(directory, "analysis_report.html"))
  invisible(directory)
}

write_analysis_bundle <- function(result, file) {
  folder <- tempfile("oncology-export-"); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE), add = TRUE)
  export_analysis(result, folder, include_figures = TRUE)
  # Compiled in-process ZIP avoids an external executable in browser R.
  zip::zipr(zipfile = file, files = list.files(folder), root = folder)
  invisible(file)
}
