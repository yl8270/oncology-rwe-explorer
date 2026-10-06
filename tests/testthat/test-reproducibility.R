testthat::test_that("simulation fixes its RNG algorithm and restores caller state", {
  kinds <- RNGkind(); had <- exists(".Random.seed", .GlobalEnv, inherits=FALSE)
  if (had) saved <- .Random.seed
  on.exit({ do.call(RNGkind, as.list(kinds)); if (had) assign(".Random.seed", saved, .GlobalEnv) })
  reference <- generate_synthetic(600, 732)
  RNGkind("L'Ecuyer-CMRG"); set.seed(99); before <- .Random.seed
  testthat::expect_identical(generate_synthetic(600, 732), reference)
  testthat::expect_identical(.Random.seed, before)
  testthat::expect_identical(RNGkind()[1], "L'Ecuyer-CMRG")
  rm(".Random.seed", envir=.GlobalEnv)
  invisible(generate_synthetic(600, 732))
  testthat::expect_false(exists(".Random.seed", .GlobalEnv, inherits=FALSE))
})

testthat::test_that("unselected expanded missingness is descriptive and does not invalidate core", {
  d <- construct_cohort(generate_synthetic(1000, 733))$data
  d$income[] <- NA
  testthat::expect_gt(nrow(prepare_model_sample(d, "core")$data), 50)
  expanded <- prepare_model_sample(d, "expanded", check=FALSE)
  testthat::expect_equal(sum(expanded$retention$analysis_n), 0)
  testthat::expect_error(prepare_model_sample(d, "expanded"), "sample")
})

testthat::test_that("failed bootstrap attempts are counted and their reasons exported", {
  cfg <- default_config(); cfg$n <- 1000; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg)
  cfg$bootstrap_reps <- 10
  broken <- r$data; broken$treatment <- 0
  b <- bootstrap_fixed_time(broken, cfg, fixed_time_survival(r$data, cfg$horizon_months))
  testthat::expect_equal(b$audit$attempted, 10)
  testthat::expect_equal(b$audit$failed, 10)
  testthat::expect_equal(nrow(b$failures), 10)
  testthat::expect_true(all(nchar(b$failures$reason) > 0))
  testthat::expect_true(all(is.na(b$table$lower_95)))
})

testthat::test_that("report and PDFs describe the same run with escaped HTML and numeric CSVs", {
  cfg <- default_config(); cfg$n <- 1000; cfg$bootstrap_reps <- 0
  progress <- numeric(); r <- run_analysis(cfg, function(value, detail) progress <<- c(progress,value))
  testthat::expect_true(all(diff(progress) >= 0)); testthat::expect_equal(tail(progress,1),1)
  r$alerts <- c(r$alerts, "<script>fixture</script>")
  folder <- tempfile(); on.exit(unlink(folder,recursive=TRUE))
  export_analysis(r,folder,include_figures=TRUE)
  report <- paste(readLines(file.path(folder,"analysis_report.html")),collapse="\n")
  testthat::expect_match(report,"&lt;script&gt;fixture&lt;/script&gt;",fixed=TRUE)
  testthat::expect_false(grepl("<script>",report,fixed=TRUE))
  testthat::expect_match(report,"percentage points",fixed=TRUE)
  testthat::expect_equal(read.csv(file.path(folder,"fixed_time_survival.csv"))$estimate,r$fixed$estimate)
  for (name in c("survival","balance","propensity_overlap","cox")) {
    con <- file(file.path(folder,paste0(name,".pdf")),"rb")
    signature <- readChar(con,4,useBytes=TRUE); close(con)
    testthat::expect_equal(signature,"%PDF")
  }
  testthat::expect_true(file.exists(file.path(folder,"bootstrap_failures.csv")))
})
