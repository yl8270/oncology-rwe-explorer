testthat::test_that("SMD uses the same reference denominator after weighting", {
  x <- c(0,2,2,4); a <- c(0,0,1,1)
  testthat::expect_equal(standardized_difference(x,a), 2)
  testthat::expect_equal(standardized_difference(x,a,c(1,3,3,1)), 1)
  testthat::expect_identical(standardized_difference(rep(2,4), a), 0)
})

testthat::test_that("weighted KM matches a hand-computed tied-risk-set example", {
  d <- data.frame(treatment = c(0,0,0,1,1), time_months = c(1,1,3,2,4),
                  event = c(1,0,1,1,0), weight = c(2,1,1,1,1))
  # At t=1, weighted death mass 2 / risk mass 4 -> S=.5.
  testthat::expect_equal(survival_at(d,0,1), .5)
  testthat::expect_equal(survival_at(d,0,2), .5)
  testthat::expect_equal(survival_at(d,0,3), 0)
  testthat::expect_true(is.na(survival_at(d,0,5)))
})

testthat::test_that("binary weights follow their definitions and OW balances fitted features", {
  cfg <- default_config(); cfg$n <- 1500; cfg$ps_spec <- "expanded"; cfg$method <- "overlap"
  d <- prepare_model_sample(construct_cohort(generate_synthetic(1500, 126))$data, "expanded")$data
  f <- fit_weights(d, cfg); z <- f$data
  testthat::expect_equal(z$overlap, ifelse(z$treatment == 1, 1 - z$ps, z$ps))
  testthat::expect_equal(z$iptw, ifelse(z$treatment == 1, mean(z$treatment)/z$ps, (1-mean(z$treatment))/(1-z$ps)))
  testthat::expect_true(all(z$weight > 0 & z$weight < 1))
  balance <- balance_table(z)
  testthat::expect_lt(max(balance$abs_weighted, na.rm = TRUE), 1e-6)
  testthat::expect_lte(effective_n(z$weight), nrow(z) + 1e-8)
})

testthat::test_that("cluster sandwich inference is invariant to global weight scaling", {
  cfg <- default_config(); cfg$n <- 1500
  d <- prepare_model_sample(construct_cohort(generate_synthetic(1500,127))$data,"core")$data
  d <- fit_weights(d,cfg)$data
  f <- checked_cox(survival::Surv(time_months,event) ~ treatment,d)
  d$weight <- d$weight * 7
  g <- checked_cox(survival::Surv(time_months,event) ~ treatment,d)
  testthat::expect_equal(unname(coef(f)),unname(coef(g)),tolerance=1e-8)
  testthat::expect_equal(unname(vcov(f)),unname(vcov(g)),tolerance=1e-8)
  testthat::expect_false(is.null(f$naive.var))
})

testthat::test_that("unsupported horizons and sparse subgroups are withheld", {
  cfg <- default_config(); cfg$n <- 1000; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg)
  fixed <- fixed_time_survival(r$data,1000)
  testthat::expect_false(fixed$supported)
  testthat::expect_true(all(is.na(fixed$table$estimate)))
  d <- r$data; d$sg_test <- factor(c("Rare", rep("Common",nrow(d)-1)))
  s <- subgroup_analysis(d,"sg_test")
  testthat::expect_true(is.na(s$interaction_p))
  testthat::expect_match(s$status,"Suppressed")
})

testthat::test_that("bootstrap refits PS, records successes and preserves RNG", {
  cfg <- default_config(); cfg$n <- 1500; cfg$bootstrap_reps <- 10
  set.seed(80); old <- .Random.seed
  r <- run_analysis(cfg)
  testthat::expect_identical(.Random.seed, old)
  testthat::expect_equal(r$bootstrap$audit$successful + r$bootstrap$audit$failed,10)
  testthat::expect_match(r$bootstrap$audit$status,"PS refit")
  testthat::expect_true(all(r$fixed$lower_95 <= r$fixed$upper_95))
  repeat_result <- run_analysis(cfg)
  testthat::expect_equal(r$bootstrap$draws,repeat_result$bootstrap$draws)
})

testthat::test_that("pooled subgroup effects and interaction match direct covariance contrasts", {
  cfg <- default_config(); cfg$n <- 2500; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg)
  # Pooled interaction shares one baseline hazard, so compare to a direct
  # coefficient/covariance contrast, not separate-baseline subgroup models.
  d <- r$data; d$sg <- d$sex
  f <- checked_cox(survival::Surv(time_months,event) ~ treatment * sg,d)
  b <- coef(f); V <- vcov(f)
  testthat::expect_equal(r$subgroup$table$hr[1], unname(exp(b["treatment"])))
  testthat::expect_equal(r$subgroup$table$hr[2], unname(exp(b["treatment"] + b["treatment:sgMale"])))
  testthat::expect_equal(r$subgroup$interaction_p,
    unname(pchisq(b["treatment:sgMale"]^2/V["treatment:sgMale","treatment:sgMale"],1,lower.tail=FALSE)))
})
