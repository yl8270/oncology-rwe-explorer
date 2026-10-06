overview_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    panel("An inspectable oncology RWE workflow",
      shiny::p(class="intro-text", "Define the study first, inspect the weights, then interpret survival. This workspace demonstrates the full analysis path using independently simulated DLBCL and SCLC cohorts."),
      shiny::div(class="workflow-strip",
        lapply(c("01 · Define cohort", "02 · Choose target", "03 · Check balance", "04 · Estimate survival", "05 · Reproduce"),
          function(x) shiny::div(class="workflow-step",x)))),
    shiny::uiOutput(ns("summary")),
    shiny::fluidRow(shiny::column(6,panel("Two declared study designs",
      shiny::h4("DLBCL · chemotherapy ± RT"), shiny::p("Adult stage I–II. Both arms have chemotherapy documented by day 365; RT follows chemotherapy. Follow-up starts at the day-365 landmark."),
      shiny::h4("SCLC · chemotherapy ± IO"), shiny::p("Adult extensive-stage disease. IO is documented on or after chemotherapy by day 90. This is a new synthetic demonstration design."))),
      shiny::column(6,panel("What changes when you change weights?",
        shiny::h4("Stabilized IPTW → ATE"),shiny::p("Targets the eligible complete-case landmark population, under identification assumptions."),
        shiny::h4("Overlap weights → ATO"),shiny::p("Targets individuals with greater treatment equipoise. The target population changes."),
        shiny::p("All run outputs use one completed configuration. Modified controls are applied only after another successful run.")))),
    panel("Read the demonstration critically",
      shiny::p("Synthetic effects are not clinical or disparity findings. Check complete-case retention, every covariate level, weight tails and time-point support. A successful fit is only one checkpoint."),
      shiny::p("Subgroup interactions are exploratory; weighted Cox intervals condition on estimated weights. Fixed-time intervals refit PS in facility bootstrap resamples.")))
}

overview_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$summary <- shiny::renderUI({
    r <- result()
    if (is.null(r)) return(shiny::div(class="welcome-card",
      shiny::h3("Start with a synthetic study"),
      shiny::p("Choose a disease and analysis target in Study configuration, then press Run analysis. Defaults provide a complete example with 2,500 fictional records."),
      shiny::div(class="welcome-tags",shiny::span("No data upload"),shiny::span("Reproducible seed"),shiny::span("Facility-cluster inference"))))
    s <- result_summary(r)
    shiny::tagList(shiny::div(class="metrics summary-metrics",
      shiny::div(class="metric",shiny::span("Model sample"),shiny::strong(format(nrow(r$data),big.mark=",")),shiny::tags$small(sprintf("%.1f%% retained after missingness",s$retention))),
      shiny::div(class="metric",shiny::span("Effective sample size"),shiny::strong(format(s$ess,big.mark=",")),shiny::tags$small("Sum of arm-specific ESS")),
      shiny::div(class="metric",shiny::span("Absolute survival contrast"),shiny::strong(s$difference),shiny::tags$small(sprintf("Treated minus control at %g months",r$config$horizon_months))),
      shiny::div(class="metric",shiny::span("Residual imbalance"),shiny::strong(as.character(s$imbalance)),shiny::tags$small("Displayed features with |SMD| ≥0.10"))),
      panel("Completed run at a glance",
        shiny::p(shiny::strong(weighting_label(r$config))," · ",estimand_label(r$config)),
        shiny::p("Selected-weight Cox HR: ",shiny::strong(s$hr)),
        shiny::p("Use Survival for the absolute contrast and its bootstrap interval. Use Weighting & Balance to see which diagnostic thresholds remain flagged.")))
  })
})
