packages <- c("shiny", "survival", "ggplot2", "jsonlite", "htmltools", "zip", "testthat")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
# setup-r supplies a Linux binary repository in CI; local installations use CRAN.
repository <- Sys.getenv("RSPM", unset = "")
if (!nzchar(repository)) repository <- "https://cloud.r-project.org"
options(timeout = max(300, getOption("timeout")))
if (length(missing)) install.packages(missing, repos = repository)
still_missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(still_missing)) stop("Dependencies unavailable after installation: ", paste(still_missing, collapse = ", "))
message("Dependencies available. Run shiny::runApp('.') from the repository root.")
