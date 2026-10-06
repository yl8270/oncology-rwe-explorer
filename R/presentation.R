display_table <- function(d) {
  if ("variable" %in% names(d)) d$variable <- variable_label(d$variable)
  if ("covariate" %in% names(d)) d$covariate <- variable_label(d$covariate)
  labels <- c(step = "Eligibility step", n_before = "Before", n_excluded = "Excluded", n_after = "Remaining",
    treatment = "Treatment", arm = "Treatment", n = "Observed N", events = "Deaths",
    eligible_n = "Landmark eligible", analysis_n = "Model sample", excluded_missing_n = "Excluded: missing",
    retention_pct = "Retention (%)", specification = "Adjustment set", variable = "Characteristic", level = "Summary / level",
    control_observed = "Control: observed", treated_observed = "Treated: observed",
    control_weighted = "Control: weighted", treated_weighted = "Treated: weighted",
    missing_n = "Missing N", missing_pct = "Missing (%)", disposition = "Disposition",
    covariate = "Characteristic / level", unweighted_smd = "SMD before", weighted_smd = "SMD after",
    abs_unweighted = "|SMD| before", abs_weighted = "|SMD| after", ess = "Effective N",
    weight_sum = "Weight sum", weight_min = "Minimum weight", weight_median = "Median weight",
    weight_p99 = "99th percentile", weight_max = "Maximum weight", ps_min = "Minimum PS", ps_max = "Maximum PS",
    extreme_ps_pct = "PS outside .05–.95 (%)", model = "Model", hr = "HR", lower_95 = "95% CI lower",
    upper_95 = "95% CI upper", p_wald = "Wald p", variance = "Variance estimator",
    chisq = "Chi-square", df = "df", p = "Diagnostic p", term = "Term", interpretation = "Interpretation",
    subgroup = "Subgroup", observed_at_risk = "Observed at risk", weighted_risk_mass = "Weighted risk mass",
    risk_set_ess = "Risk-set ESS", month_after_landmark = "Months after landmark",
    quantity = "Quantity", estimate = "Estimate", horizon_months_after_landmark = "Months after landmark",
    requested = "Requested", attempted = "Attempted", successful = "Successful", failed = "Failed",
    status = "Status", check = "QC checkpoint", passed = "Passed")
  idx <- names(d) %in% names(labels)
  names(d)[idx] <- unname(labels[names(d)[idx]])
  d
}

format_estimate <- function(value, lower = NA_real_, upper = NA_real_, percent = FALSE) {
  if (!is.finite(value)) return("Withheld: insufficient support")
  scale <- if (percent) 100 else 1
  text <- sprintf(if (percent) "%.1f%%" else "%.2f", scale * value)
  if (all(is.finite(c(lower, upper))))
    text <- paste0(text, sprintf(if (percent) " (95%% CI %.1f–%.1f%%)" else " (95%% CI %.2f–%.2f)", scale * lower, scale * upper))
  text
}

fixed_time_display <- function(d) {
  out <- data.frame(Quantity = d$quantity, `Estimate / 95% interval` = vapply(seq_len(nrow(d)), function(j) {
    if (j == 3) {
      if (!is.finite(d$estimate[j])) return("Withheld: insufficient support")
      point <- sprintf("%+.1f percentage points", 100 * d$estimate[j])
      if (all(is.finite(c(d$lower_95[j], d$upper_95[j]))))
        point <- paste0(point, sprintf(" (95%% CI %+.1f to %+.1f pp)", 100*d$lower_95[j], 100*d$upper_95[j]))
      point
    } else format_estimate(d$estimate[j], d$lower_95[j], d$upper_95[j], percent = TRUE)
  }, character(1)), `Months after landmark` = d$horizon_months_after_landmark, check.names = FALSE)
  out
}

result_summary <- function(r) {
  hr <- r$cox$table[r$cox$table$model == "Selected weighting", ]
  difference <- r$fixed[3, ]
  smd <- r$balance$abs_weighted
  list(hr = format_estimate(hr$hr, hr$lower_95, hr$upper_95),
    difference = if (is.finite(difference$estimate)) sprintf("%+.1f pp", 100*difference$estimate) else "Withheld",
    imbalance = sum(smd >= .1, na.rm = TRUE),
    ess = round(sum(r$weights$diagnostics$ess)),
    retention = 100 * nrow(r$data) / nrow(r$cohort))
}

write_analysis_report <- function(r, path) {
  escape <- function(x) as.character(htmltools::htmlEscape(as.character(x)))
  table_html <- function(d) {
    d <- display_table(d)
    header <- paste0("<th>", escape(names(d)), "</th>", collapse = "")
    body <- vapply(seq_len(nrow(d)), function(j) paste0("<tr>",
      paste0("<td>", escape(vapply(d, function(x) if (is.na(x[j])) "Not estimated" else as.character(x[j]), character(1))),
             "</td>", collapse = ""), "</tr>"), character(1))
    paste0("<div class='scroll'><table><thead><tr>", header, "</tr></thead><tbody>", paste(body, collapse=""), "</tbody></table></div>")
  }
  summary <- result_summary(r)
  blocks <- c("<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>",
    "<title>Oncology RWE Explorer — completed analysis</title><style>body{font:15px/1.6 Arial,sans-serif;color:#173547;margin:36px auto;max-width:1100px;padding:0 20px}h1,h2{line-height:1.2}h2{margin-top:36px}table{border-collapse:collapse;width:100%;font-size:12px}td,th{padding:8px;text-align:left;border-bottom:1px solid #ddd}thead{border-top:2px solid #173547;border-bottom:2px solid #173547}.scroll{overflow-x:auto}.badge{background:#e2f1ef;padding:8px 12px;display:inline-block}pre{white-space:pre-wrap;background:#f5f7f8;padding:16px;font-size:12px}</style>",
    "<h1>Oncology RWE Explorer</h1><p class='badge'>100% SYNTHETIC DATA · COMPLETED RUN SNAPSHOT</p>",
    paste0("<p><strong>", escape(r$config$disease), " · ", escape(paste(r$preset$arms,collapse=" vs ")), "</strong></p>"),
    paste0("<p>", escape(estimand_label(r$config)), "</p>"),
    sprintf("<p>Seed %d · %d model individuals · %d deaths · %g months after day-%d landmark</p>",r$config$seed,nrow(r$data),sum(r$data$event),r$config$horizon_months,r$preset$landmark_days),
    paste0("<p>Selected-weight Cox HR: <strong>",escape(summary$hr),"</strong>. Absolute survival difference: <strong>",escape(summary$difference),"</strong>.</p>"),
    "<p>Simulated associations are not clinical evidence. Weighted Cox intervals condition on fitted weights; absolute survival intervals refit PS using facility bootstrap. Subgroups and PH diagnostics are exploratory.</p>",
    "<h2>Diagnostics requiring attention</h2>", if (length(r$alerts)) paste0("<ul>",paste0("<li>",escape(r$alerts),"</li>",collapse=""),"</ul>") else "<p>No displayed diagnostic thresholds were crossed; this does not establish causal identification.</p>",
    "<h2>Cohort lineage</h2>",table_html(r$flow),
    "<h2>Retention</h2>",table_html(r$retention_comparison),
    "<h2>Absolute survival</h2>",table_html(fixed_time_display(r$fixed)),
    "<h2>Cox regression</h2>",table_html(format_p_column(r$cox$table,"p_wald")),
    "<h2>Exploratory subgroup interaction</h2>",paste0("<p>Global interaction p = ",escape(format.pval(r$subgroup$interaction_p,digits=3,eps=.0001,na.form="Withheld")),". ",escape(r$subgroup$status),"</p>"),table_html(r$subgroup$table),
    "<h2>Baseline Table 1</h2>",table_html(r$table1),
    "<p>Observed counts and nonmissing percentages; weighted proportions and population SD. Missing percentages use all individuals in the arm.</p>",
    "<h2>Balance</h2>",table_html(r$balance),
    "<h2>Bootstrap audit</h2>",table_html(r$bootstrap$audit),
    "<h2>Reproduce this run</h2><p>Use the accompanying config.json with scripts/run_example.R in the source repository. CSVs retain unrounded numeric estimates. Vector PDFs are included when exported from the app.</p>",
    paste0("<pre>",escape(jsonlite::toJSON(r$manifest,auto_unbox=TRUE,pretty=TRUE,na="null")),"</pre></html>"))
  writeLines(blocks, path, useBytes = TRUE)
  invisible(path)
}
