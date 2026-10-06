load_engine <- function(root = ".", envir = parent.frame()) {
  files <- c("config.R", "synthetic.R", "cohort.R", "weighting.R", "descriptives.R", "survival.R",
             "pipeline.R", "plots.R", "presentation.R", "modules.R", "overview.R", "app_factory.R")
  for (file in files) sys.source(file.path(root, "R", file), envir = envir)
  invisible(files)
}
