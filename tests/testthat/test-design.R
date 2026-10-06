testthat::test_that("simulation is deterministic, fictional and preserves RNG", {
  set.seed(40); old <- .Random.seed
  d <- generate_synthetic(1000, 123)
  testthat::expect_identical(.Random.seed, old)
  testthat::expect_identical(d, generate_synthetic(1000, 123))
  testthat::expect_true(all(d$synthetic))
  testthat::expect_true(all(grepl("^SYN-DLBCL-", d$synthetic_id)))
  testthat::expect_false(attr(d, "provenance")$restricted_data_used)
  testthat::expect_false(attr(d, "provenance")$empirical_calibration)
})

testthat::test_that("day boundaries, treatment windows and survival coding are explicit", {
  d <- generate_synthetic(1000, 123, missing_rate = 0)
  d$age <- 60; d$stage <- factor(rep("I",1000)); d$treatment <- 0
  d$chemo_day <- 10; d$adjunct_day <- NA_real_; d$exit_day <- 1000; d$event <- 0
  d$exit_day[1:3] <- c(365,364,366)
  d$event[4] <- NA; d$exit_day[5] <- NA; d$event[6] <- 9; d$exit_day[7] <- -1
  d$treatment[8:10] <- 1; d$adjunct_day[8:10] <- c(10,365,366)
  d$chemo_day[11:12] <- c(365,366)
  r <- construct_cohort(d)
  ids <- as.integer(sub(".*-", "", r$data$synthetic_id))
  testthat::expect_true(all(c(3,9,11) %in% ids))
  testthat::expect_false(any(c(1,2,4,5,6,7,8,10,12) %in% ids))
  testthat::expect_equal(sum(r$flow$n_excluded) + nrow(r$data), 1000)
  testthat::expect_equal(r$pre_landmark$n, c(0,1,1))
  d$synthetic_id[2] <- d$synthetic_id[1]
  testthat::expect_error(construct_cohort(d), "unique")
})

testthat::test_that("SCLC permits same-day adjunct and declares a distinct window", {
  d <- generate_synthetic(1000, 124, "SCLC", missing_rate = 0)
  d$stage <- factor(rep("Extensive",1000)); d$age <- 60; d$treatment <- rep(0:1, 500)
  d$chemo_day <- 10; d$adjunct_day <- ifelse(d$treatment == 1, 10, NA)
  d$exit_day <- 500; d$event <- 0
  r <- construct_cohort(d, "SCLC")
  testthat::expect_equal(nrow(r$data), 1000)
  testthat::expect_equal(r$data$time_months, rep(410/(365.25/12),1000))
})

testthat::test_that("missing data restrict the model without fabricating survival", {
  d <- construct_cohort(generate_synthetic(1500, 125, missing_rate = .2))$data
  core <- prepare_model_sample(d, "core"); expanded <- prepare_model_sample(d, "expanded")
  testthat::expect_lte(nrow(expanded$data), nrow(core$data))
  testthat::expect_equal(sum(expanded$retention$analysis_n), nrow(expanded$data))
  testthat::expect_equal(sum(expanded$retention$excluded_missing_n) + nrow(expanded$data), nrow(d))
  testthat::expect_identical(expanded$data$event, d$event[match(expanded$data$synthetic_id, d$synthetic_id)])
})
