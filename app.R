required <- c("shiny", "survival", "ggplot2", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install dependencies first with Rscript scripts/install_dependencies.R. Missing: ", paste(missing, collapse = ", "))
source("R/load.R", local = TRUE)
load_engine(".", environment())
create_app()
