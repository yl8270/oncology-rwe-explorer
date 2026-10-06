if (!file.exists("app.R")) stop("Run this script from the repository root.")
source("R/load.R"); load_engine()
args <- commandArgs(trailingOnly = TRUE)
cfg <- if (length(args) >= 1) jsonlite::read_json(args[1], simplifyVector = TRUE) else default_config()
output_dir <- if (length(args) >= 2) args[2] else "outputs/example"
r <- run_analysis(cfg)
export_analysis(r, output_dir, include_figures = TRUE)
print(r$cox$table); print(r$qc)
message("Synthetic example written to ",output_dir)
