if (!file.exists("app.R")) stop("Run this script from the repository root.")
if (!requireNamespace("shinylive", quietly = TRUE)) stop("Install shinylive 0.5.0 to build the website.")
args <- commandArgs(trailingOnly = TRUE)
destination <- if (length(args)) args[1] else "outputs/site"
staging <- tempfile("oncology-public-app-"); dir.create(staging)
tryCatch({
  # Only the runnable public app is bundled; no notebook, dataset or output directory.
  file.copy("app.R", staging)
  dir.create(file.path(staging, "R")); dir.create(file.path(staging, "www"))
  file.copy(list.files("R", pattern = "\\.R$", full.names = TRUE), file.path(staging, "R"))
  file.copy("www/style.css", file.path(staging, "www"))
  shinylive::export(staging, destination, assets_version = "0.10.12", wasm_packages = TRUE,
                    template_params = list(title = "Oncology RWE Explorer"))
  writeLines("", file.path(destination, ".nojekyll"))
}, finally = unlink(staging, recursive = TRUE))
message("Browser Shiny website built at ", destination)
