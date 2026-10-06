# Authored toy distributions only. This function has no file or network inputs.
generate_synthetic <- function(n = 2500L, seed = 20261005L, disease = "DLBCL",
                               scenario = "standard", missing_rate = .04) {
  cfg <- default_config(disease)
  cfg$n <- n; cfg$seed <- seed; cfg$scenario <- scenario; cfg$missing_rate <- missing_rate
  validate_config(cfg)
  preset <- study_preset(disease)
  with_local_seed(seed, {
    L <- preset$landmark_days
    facility_index <- sample(seq_len(60), n, replace = TRUE)
    facility_kind <- sample(c("Academic", "Community", "Integrated"), 60, TRUE)
    facility_type <- factor(facility_kind[facility_index], levels = c("Academic", "Community", "Integrated"))
    # Facilities cluster treatment assignment, not an unmeasured survival confounder.
    facility_assignment <- rnorm(60, 0, .15)[facility_index]
    age <- pmin(90, pmax(16, round(rnorm(n, 63, 13))))
    sex <- factor(sample(c("Female", "Male"), n, TRUE), levels = c("Female", "Male"))
    race <- factor(sample(c("Black", "Hispanic", "Other"), n, TRUE, c(.35, .3, .35)),
                   levels = c("Black", "Hispanic", "Other"))
    comorbidity <- rbinom(n, 2, plogis(-1 + .025 * (age - 60)))
    stage <- factor(if (disease == "DLBCL") sample(c("I", "II", "III", "IV"), n, TRUE, c(.40,.40,.12,.08))
                    else sample(c("Extensive", "Limited"), n, TRUE, c(.85,.15)))
    year <- sample(2010:2022, n, TRUE)
    insurance <- factor(ifelse(runif(n) < plogis(-.4 + .045 * (age - 60)), "Public", "Private"))
    income <- factor(sample(c("Lower", "Middle", "Higher"), n, TRUE), levels = c("Lower", "Middle", "Higher"))
    lp <- -.25 - .035 * (age - 60) - .35 * comorbidity + .15 * (sex == "Male") +
      .15 * (race == "Hispanic") + .2 * (stage %in% c("II", "Extensive")) +
      .055 * (year - 2016) + .20 * (insurance == "Private") + .20 * (income == "Higher") +
      .25 * (facility_type == "Academic") + facility_assignment
    if (scenario == "poor_overlap") lp <- 2 * lp + 1 * (age < 55) - 1 * (age > 75)
    assignment_ps <- plogis(lp)
    treatment <- rbinom(n, 1, assignment_ps)
    chemo_day <- sample(5:45, n, TRUE)
    adjunct_day <- ifelse(treatment == 1, chemo_day +
      sample(if (disease == "DLBCL") 20:280 else 0:40, n, TRUE), NA_real_)
    baseline_lp <- .025 * (age - 60) + .3 * comorbidity + .1 * (sex == "Male") +
      .2 * (stage %in% c("II", "Extensive")) - .15 * (insurance == "Private") -
      .12 * (income == "Higher") - .12 * (facility_type == "Academic") - .015 * (year - 2016)
    # Shared pre-landmark hazard; exposure effect begins only after L.
    rate <- if (disease == "DLBCL") .00032 else .0014
    pre_rate <- rate * exp(baseline_lp)
    pre_event <- rexp(n, pre_rate)
    hr <- if (scenario == "null") 1 else if (disease == "DLBCL") .72 else .78
    post_rate <- rate * exp(baseline_lp) * hr^treatment
    if (scenario == "non_ph") {
      split <- 365
      post_first <- rexp(n, rate * exp(baseline_lp) * .50^treatment)
      post_event <- ifelse(post_first <= split, post_first,
                           split + rexp(n, rate * exp(baseline_lp) * 1.45^treatment))
    } else post_event <- rexp(n, post_rate)
    event_time <- ifelse(pre_event <= L, pre_event, L + post_event)
    # Censoring is independent of baseline, treatment and event times in this toy DGP.
    censor_time <- rexp(n, 1 / 9000) + 15
    admin_time <- runif(n, L + 3*365, L + 8*365)
    exit_day <- pmin(event_time, censor_time, admin_time)
    event <- as.integer(event_time <= pmin(censor_time, admin_time))
    # A recorded treatment cannot start after observed death/censoring.
    chemo_day[chemo_day > exit_day] <- NA_real_
    adjunct_day[!is.na(adjunct_day) & adjunct_day > exit_day] <- NA_real_
    # Intentionally imperfect ascertainment exercises the cohort QC.
    chemo_day[runif(n) < .015] <- L + 10
    treatment[runif(n) < .01] <- NA_integer_
    adjunct_day[runif(n) < .015 & !is.na(treatment) & treatment == 1] <- NA_real_
    out <- data.frame(synthetic_id = sprintf("SYN-%s-%06d", disease, seq_len(n)),
      synthetic = TRUE, disease = disease, facility_id = sprintf("SIM-F%03d", facility_index),
      age = age, sex = sex, race_ethnicity = race, comorbidity = comorbidity, stage = stage,
      diagnosis_year = year, insurance = insurance, income = income, facility_type = facility_type,
      treatment = treatment, chemo_day = as.numeric(chemo_day), adjunct_day = as.numeric(adjunct_day),
      exit_day = exit_day, event = event)
    # Missingness depends on observed age; complete-case target is explicit.
    for (v in c("comorbidity", "insurance", "income", "facility_type")) {
      multiplier <- if (v == "comorbidity") .25 else 1.5
      prob <- pmin(.7, missing_rate * multiplier * ifelse(age < 50, 1.5, 1))
      out[runif(n) < prob, v] <- NA
    }
    idx <- runif(n) < .005
    out$event[idx] <- NA_integer_
    out$exit_day[runif(n) < .005] <- NA_real_
    attr(out, "provenance") <- list(source = "authored-simulation-v1", seed = seed,
      disease = disease, scenario = scenario, n = n, missing_rate = missing_rate,
      conditional_post_landmark_hr = if (scenario == "non_ph") NA_real_ else hr,
      rng = list(kind = "Mersenne-Twister", normal_kind = "Inversion", sample_kind = "Rejection"),
      empirical_calibration = FALSE, restricted_data_used = FALSE)
    out
  })
}
