packages <- c("shiny", "survival", "ggplot2", "jsonlite", "htmltools", "testthat")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Dependencies available. Run shiny::runApp('.') from the repository root.")
