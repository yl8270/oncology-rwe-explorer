testthat::test_that("in-process bundle preserves the run and all numeric results", {
  cfg <- default_config(); cfg$n <- 1000; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg)
  archive <- tempfile(fileext=".zip"); extracted <- tempfile()
  on.exit(unlink(c(archive,extracted),recursive=TRUE))
  write_analysis_bundle(r, archive)
  listing <- zip::zip_list(archive)
  testthat::expect_equal(nrow(listing),30)
  testthat::expect_true(all(c("config.json","analysis_report.html","survival.pdf","bootstrap_failures.csv") %in% listing$filename))
  zip::unzip(archive,exdir=extracted)
  testthat::expect_equal(jsonlite::read_json(file.path(extracted,"config.json"),simplifyVector=TRUE),cfg)
  testthat::expect_equal(read.csv(file.path(extracted,"cox.csv"))$hr,r$cox$table$hr)
  testthat::expect_true(all(read.csv(file.path(extracted,"synthetic_generated.csv"))$synthetic))
})
