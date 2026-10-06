validate_synthetic_schema <- function(d) {
  required <- c("synthetic_id", "synthetic", "disease", "facility_id", "treatment",
                "chemo_day", "adjunct_day", "exit_day", "event", baseline_variables("expanded"))
  if (!all(required %in% names(d))) stop("Synthetic schema is incomplete.")
  if (anyNA(d$synthetic) || !all(d$synthetic) ||
      !identical(attr(d, "provenance")$source, "authored-simulation-v1"))
    stop("Only internally generated synthetic data are supported.")
  if (anyNA(d$synthetic_id) || anyDuplicated(d$synthetic_id) ||
      any(!grepl("^SYN-", d$synthetic_id))) stop("Synthetic IDs must be unique and nonmissing.")
  numeric_fields <- c("age", "comorbidity", "diagnosis_year", "treatment", "chemo_day", "adjunct_day", "exit_day", "event")
  if (!all(vapply(d[numeric_fields], is.numeric, logical(1)))) stop("Invalid numeric schema.")
  invisible(d)
}

construct_cohort <- function(d, disease = "DLBCL") {
  validate_synthetic_schema(d)
  preset <- study_preset(disease); L <- preset$landmark_days
  flow <- data.frame(step = "Generated synthetic records", n_before = nrow(d), n_excluded = 0L, n_after = nrow(d))
  keep_step <- function(label, keep) {
    keep[is.na(keep)] <- FALSE
    before <- nrow(d)
    d <<- d[keep, , drop = FALSE]
    flow <<- rbind(flow, data.frame(step = label, n_before = before,
                                    n_excluded = before - nrow(d), n_after = nrow(d)))
  }
  keep_step("Disease preset", d$disease == disease)
  keep_step("Adults aged 18 or older", is.finite(d$age) & d$age >= 18)
  keep_step(if (disease == "DLBCL") "Stage I–II" else "Extensive-stage disease", d$stage %in% preset$eligible_stages)
  keep_step("Confirmed binary treatment status", d$treatment %in% c(0, 1))
  keep_step(sprintf("Chemotherapy documented by day %d, both arms", L),
            is.finite(d$chemo_day) & d$chemo_day >= 0 & d$chemo_day <= L)
  correct_sequence <- if (disease == "DLBCL") d$adjunct_day > d$chemo_day else d$adjunct_day >= d$chemo_day
  keep_step("Treated arm: documented adjunct within window and valid sequence",
            d$treatment == 0 | (is.finite(d$adjunct_day) & d$adjunct_day <= L & correct_sequence))
  keep_step("Valid observed survival time and event coding",
            is.finite(d$exit_day) & d$exit_day > 0 & d$event %in% c(0, 1))
  keep_step("Recorded treatment starts within observed follow-up",
            d$chemo_day <= d$exit_day & (d$treatment == 0 | d$adjunct_day <= d$exit_day))
  before_landmark <- data.frame(disposition = c("Death before landmark", "Censored before landmark", "Exactly at landmark"),
    n = c(sum(d$exit_day < L & d$event == 1), sum(d$exit_day < L & d$event == 0), sum(d$exit_day == L)))
  keep_step(sprintf("Observed alive and followed beyond day %d", L), d$exit_day > L)
  if (nrow(d) < 50 || length(unique(d$treatment)) < 2) stop("Insufficient eligible cohort or one treatment arm absent.")
  d$time_months <- (d$exit_day - L) / (365.25 / 12)
  d$age_group <- factor(ifelse(d$age <= 60, "Age ≤60", "Age >60"), levels = c("Age ≤60", "Age >60"))
  d$treatment_label <- factor(preset$arms[d$treatment + 1], levels = preset$arms)
  stopifnot(all(d$time_months > 0), all(flow$n_before - flow$n_excluded == flow$n_after),
            sum(flow$n_excluded) + nrow(d) == flow$n_before[1])
  list(data = droplevels(d), flow = flow, pre_landmark = before_landmark)
}
