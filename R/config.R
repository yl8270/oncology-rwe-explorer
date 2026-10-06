study_preset <- function(disease = "DLBCL") {
  stopifnot(disease %in% c("DLBCL", "SCLC"))
  list(disease = disease, landmark_days = if (disease == "DLBCL") 365 else 90,
       arms = if (disease == "DLBCL") c("Chemotherapy", "Chemotherapy + RT") else
         c("Chemotherapy", "Chemotherapy + IO"),
       eligible_stages = if (disease == "DLBCL") c("I", "II") else "Extensive",
       horizon_months = if (disease == "DLBCL") 48 else 18)
}

default_config <- function(disease = "DLBCL") {
  list(disease = disease, n = 2500L, seed = 20261005L, scenario = "standard",
       missing_rate = 0.04, ps_spec = "core", method = "iptw", winsorize = FALSE,
       horizon_months = study_preset(disease)$horizon_months,
       subgroup = "sex", bootstrap_reps = 50L)
}

validate_config <- function(cfg) {
  need <- names(default_config())
  if (!all(need %in% names(cfg))) stop("Incomplete analysis configuration.")
  scalar <- function(x) length(x) == 1L && !is.na(x)
  if (!all(vapply(cfg[need], scalar, logical(1)))) stop("Configuration must contain scalar values.")
  if (!cfg$disease %in% c("DLBCL", "SCLC") || !cfg$scenario %in%
      c("standard", "null", "poor_overlap", "non_ph")) stop("Unknown simulation preset.")
  if (!is.numeric(cfg$n) || cfg$n < 500 || cfg$n > 10000 || cfg$n != floor(cfg$n))
    stop("Simulation size must be an integer between 500 and 10000.")
  if (!is.numeric(cfg$seed) || cfg$seed < 1 || cfg$seed > 2e9 || cfg$seed != floor(cfg$seed))
    stop("Seed must be an integer between 1 and 2 billion.")
  if (!is.numeric(cfg$missing_rate) || cfg$missing_rate < 0 || cfg$missing_rate > .3)
    stop("Missingness must be between 0 and 0.30.")
  if (!cfg$ps_spec %in% c("core", "expanded") || !cfg$method %in% c("unweighted", "iptw", "overlap"))
    stop("Unknown PS specification or weighting method.")
  if (!is.logical(cfg$winsorize) || (cfg$winsorize && cfg$method != "iptw"))
    stop("Winsorization is available only for IPTW.")
  if (!is.numeric(cfg$horizon_months) || cfg$horizon_months < 1 || cfg$horizon_months > 60)
    stop("Horizon must be 1–60 months after landmark.")
  if (!cfg$subgroup %in% c("sex", "age_group", "race_ethnicity")) stop("Unknown subgroup.")
  if (!is.numeric(cfg$bootstrap_reps) || cfg$bootstrap_reps < 0 || cfg$bootstrap_reps > 500 ||
      cfg$bootstrap_reps != floor(cfg$bootstrap_reps)) stop("Bootstrap reps must be an integer in 0–500.")
  invisible(cfg)
}

baseline_variables <- function(spec = "core") {
  core <- c("age", "sex", "race_ethnicity", "comorbidity", "stage", "diagnosis_year")
  if (spec == "expanded") c(core, "insurance", "income", "facility_type") else core
}

estimand_label <- function(cfg) {
  if (cfg$method == "unweighted") return("Unadjusted association in the complete-case landmark cohort")
  if (cfg$method == "overlap") return("ATO: overlap population within the complete-case landmark cohort")
  if (cfg$winsorize) return("IPTW winsorization sensitivity: modified ATE weights")
  "ATE: complete-case eligible landmark population, under identification assumptions"
}

with_local_seed <- function(seed, code) {
  old_kind <- RNGkind()
  had <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had) old <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had) assign(".Random.seed", old, envir = .GlobalEnv) else
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  })
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  force(code)
}

variable_label <- function(x) {
  labels <- c(age = "Age (years)", sex = "Sex", race_ethnicity = "Simulated race / ethnicity",
    comorbidity = "Comorbidity score", stage = "Disease stage", diagnosis_year = "Diagnosis year",
    insurance = "Insurance", income = "Area income", facility_type = "Facility type",
    age_group = "Age group")
  vapply(x, function(s) {
    if (startsWith(s, "age spline basis")) return(sub("age spline basis", "Age spline basis", s))
    parts <- strsplit(s, ": ", fixed = TRUE)[[1]]
    first <- if (parts[1] %in% names(labels)) labels[[parts[1]]] else parts[1]
    paste(c(first, parts[-1]), collapse = ": ")
  }, character(1), USE.NAMES = FALSE)
}

weighting_label <- function(cfg) switch(cfg$method,
  unweighted = "Unweighted", overlap = "Overlap weights (ATO)",
  iptw = if (cfg$winsorize) "Winsorized IPTW sensitivity" else "Stabilized IPTW (ATE)")
