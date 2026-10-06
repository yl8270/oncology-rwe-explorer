if (!file.exists("app.R")) stop("Run this script from the repository root.")
testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
