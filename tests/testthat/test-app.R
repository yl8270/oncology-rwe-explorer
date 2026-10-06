testthat::test_that("both disease pipelines and all analysis targets run", {
  for (disease in c("DLBCL","SCLC")) for (method in c("unweighted","iptw","overlap")) {
    cfg <- default_config(disease); cfg$n <- 1500; cfg$method <- method; cfg$bootstrap_reps <- 0
    r <- run_analysis(cfg)
    testthat::expect_true(all(r$qc$passed))
    testthat::expect_equal(r$cox$table$n,rep(nrow(r$data),3))
    testthat::expect_true(all(r$fixed$estimate[1:2] >= 0 & r$fixed$estimate[1:2] <= 1))
    testthat::expect_equal(r$manifest$config,cfg)
  }
})

testthat::test_that("stress scenarios and explicit winsorization remain auditable", {
  for (scenario in c("null","poor_overlap","non_ph")) {
    cfg <- default_config(); cfg$scenario <- scenario; cfg$n <- 2500; cfg$bootstrap_reps <- 0
    r <- run_analysis(cfg)
    testthat::expect_true(all(r$qc$passed))
    testthat::expect_identical(r$manifest$data_provenance$scenario,scenario)
  }
  cfg <- default_config(); cfg$winsorize <- TRUE; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg)
  testthat::expect_true(all(r$data$weight >= r$weights$winsor_cutoffs[1] & r$data$weight <= r$weights$winsor_cutoffs[2]))
  testthat::expect_match(estimand_label(cfg),"modified")
})

testthat::test_that("exports include only synthetic data and the completed config", {
  cfg <- default_config(); cfg$n <- 1000; cfg$bootstrap_reps <- 0
  r <- run_analysis(cfg); folder <- tempfile(); on.exit(unlink(folder,recursive=TRUE))
  export_analysis(r,folder)
  manifest <- jsonlite::read_json(file.path(folder,"manifest.json"),simplifyVector=TRUE)
  testthat::expect_equal(manifest$config,cfg)
  testthat::expect_false(manifest$data_provenance$restricted_data_used)
  data <- read.csv(file.path(folder,"synthetic_generated.csv"))
  testthat::expect_equal(nrow(data),cfg$n)
  testthat::expect_true(all(data$synthetic))
  testthat::expect_true(file.exists(file.path(folder,"cox.csv")))
})

testthat::test_that("Shiny run actions keep results fixed until the next completed run", {
  app <- create_app()
  shiny::testServer(app$serverFuncSource(), {
    session$setInputs(disease="DLBCL",n=1000,seed=123,scenario="standard",missing_rate=.04,
      ps_spec="core",method="iptw",winsorize=FALSE,horizon_months=48,subgroup="sex",bootstrap_reps="0")
    session$setInputs(run=1)
    testthat::expect_equal(result()$config$seed,123)
    testthat::expect_true(all(result()$qc$passed))
    testthat::expect_match(as.character(output[["overview-summary"]]$html), "Model sample", fixed=TRUE)
    testthat::expect_equal(output$has_results, "TRUE")
    session$setInputs(seed=124)
    testthat::expect_equal(result()$config$seed,123)
    testthat::expect_match(as.character(output$run_status$html),"Controls changed")
    session$setInputs(run=2)
    testthat::expect_equal(result()$config$seed,124)
    session$setInputs(n=2,run=3)
    testthat::expect_match(last_error(),"Simulation size")
    testthat::expect_equal(result()$config$seed,124)
  })
})
