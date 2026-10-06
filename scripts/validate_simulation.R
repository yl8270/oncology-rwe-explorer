# Bounded validation of conditional truth. Marginal weighted HR is not
# compared with the conditional generating HR (non-collapsibility).
if (!file.exists("app.R")) stop("Run from the repository root.")
source("R/load.R"); load_engine()
rows <- list()
for (disease in c("DLBCL", "SCLC")) for (scenario in c("standard", "null")) {
  for (j in seq_len(12)) {
    cfg <- default_config(disease); cfg$n <- 6000; cfg$seed <- 4000 + j
    cfg$scenario <- scenario; cfg$ps_spec <- "expanded"; cfg$bootstrap_reps <- 0
    r <- run_analysis(cfg)
    expected <- attr(r$raw, "provenance")$conditional_post_landmark_hr
    adjusted <- r$cox$table$hr[r$cox$table$model == "Covariate-adjusted"]
    crude <- r$cox$table$hr[r$cox$table$model == "Unadjusted"]
    weighted <- r$cox$table$hr[r$cox$table$model == "Selected weighting"]
    rows[[length(rows)+1]] <- data.frame(disease=disease,scenario=scenario,seed=cfg$seed,
      truth_conditional_hr=expected,adjusted_hr=adjusted,crude_hr=crude,weighted_hr=weighted,
      analysis_n=nrow(r$data),max_ow_smd=NA_real_)
  }
}
d <- do.call(rbind,rows)
summary <- do.call(rbind,lapply(split(d,interaction(d$disease,d$scenario)),function(z) {
  truth <- z$truth_conditional_hr[1]
  data.frame(disease=z$disease[1],scenario=z$scenario[1],replicates=nrow(z),
    conditional_truth=truth,adjusted_geometric_mean_hr=exp(mean(log(z$adjusted_hr))),
    crude_geometric_mean_hr=exp(mean(log(z$crude_hr))),
    weighted_geometric_mean_hr=exp(mean(log(z$weighted_hr))),
    adjusted_mean_log_error=mean(log(z$adjusted_hr/truth)),
    adjusted_log_mcse=sd(log(z$adjusted_hr))/sqrt(nrow(z)))
}))
rownames(summary) <- NULL
# Broad deterministic sanity tolerance, not an operating-characteristic study.
stopifnot(all(abs(summary$adjusted_mean_log_error) < .10))
benefit <- summary$scenario == "standard"
stopifnot(all(abs(log(summary$adjusted_geometric_mean_hr[benefit]/summary$conditional_truth[benefit])) <
              abs(log(summary$crude_geometric_mean_hr[benefit]/summary$conditional_truth[benefit]))))
null <- summary$scenario == "null"
stopifnot(all(abs(log(summary$weighted_geometric_mean_hr[null])) < .10))
dir.create("outputs/validation",recursive=TRUE,showWarnings=FALSE)
write.csv(d,"outputs/validation/simulation_replicates.csv",row.names=FALSE)
write.csv(summary,"outputs/validation/simulation_summary.csv",row.names=FALSE)
print(summary)
message("PASS: 48 independently generated cohorts; conditional recovery and null checks. Not a coverage or power study.")
