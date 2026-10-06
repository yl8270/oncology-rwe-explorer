result_workspace <- function(content) shiny::tagList(
  shiny::conditionalPanel("output.has_results != 'TRUE'", panel("Ready when you are", shiny::p("Press Run analysis in Study configuration to populate this workspace with synthetic results."))),
  shiny::conditionalPanel("output.has_results == 'TRUE'", content))

panel <- function(title, ...) shiny::div(class = "result-panel", shiny::h3(title), ...)
table_view <- function(id) shiny::div(class = "table-scroll", shiny::tableOutput(id))
format_p_column <- function(d, column) {
  d[[column]] <- format.pval(d[[column]], digits = 3, eps = 0.0001, na.form = "Withheld")
  d
}

cohort_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(shiny::uiOutput(ns("metrics")),
    panel("Cohort lineage", table_view(ns("flow"))),
    panel("Complete-case retention", table_view(ns("retention"))),
    panel("Baseline Table 1", shiny::p("Control and treated refer to the study arms. Observed columns show n (%) or mean (sample SD). Weighted columns show percentages or mean (population SD). Category percentages use nonmissing values; missing percentages use the full arm. All columns use the same model sample."), table_view(ns("table1"))),
    panel("Missingness in the eligible landmark cohort", table_view(ns("missingness"))),
    panel("Pre-landmark disposition after ascertainment", table_view(ns("pre"))))
}

cohort_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$metrics <- shiny::renderUI({
    r <- result(); shiny::req(r)
    values <- c("Generated" = nrow(r$raw), "Landmark eligible" = nrow(r$cohort),
                "Model sample" = nrow(r$data), "Observed deaths" = sum(r$data$event))
    shiny::div(class = "metrics", lapply(names(values), function(nm)
      shiny::div(class = "metric", shiny::span(nm), shiny::strong(format(values[[nm]], big.mark = ",")))))
  })
  output$flow <- shiny::renderTable({ shiny::req(result()); display_table(result()$flow) }, rownames = FALSE)
  output$retention <- shiny::renderTable({ shiny::req(result()); display_table(result()$retention_comparison) }, digits = 1)
  output$table1 <- shiny::renderTable({ shiny::req(result()); display_table(result()$table1) }, striped = TRUE)
  output$missingness <- shiny::renderTable({ shiny::req(result()); display_table(result()$missingness) }, digits = 1)
  output$pre <- shiny::renderTable({ shiny::req(result()); display_table(result()$pre_landmark) })
})

balance_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(panel("Overlap and weight stability", shiny::fluidRow(
      shiny::column(6, shiny::plotOutput(ns("ps"))), shiny::column(6, shiny::plotOutput(ns("weights")))),
      table_view(ns("diagnostics"))),
    panel("Balance before and after weighting", shiny::plotOutput(ns("love"), height = "760px"),
      shiny::p("SMD 0.10 is a diagnostic reference, not proof of exchangeability. Variables outside the core PS are also checked. Missingness indicators appear where needed."),
      table_view(ns("balance"))))
}

balance_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$ps <- shiny::renderPlot({ shiny::req(result()); plot_ps(result()) }, res = 100)
  output$weights <- shiny::renderPlot({ shiny::req(result()); plot_weights(result()) }, res = 100)
  output$love <- shiny::renderPlot({ shiny::req(result()); plot_balance(result()) }, res = 100)
  output$diagnostics <- shiny::renderTable({ shiny::req(result()); display_table(result()$weights$diagnostics) }, digits = 3)
  output$balance <- shiny::renderTable({ shiny::req(result()); display_table(result()$balance) }, digits = 3)
})

survival_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(panel("Kaplan–Meier analysis", shiny::plotOutput(ns("km"), height = "450px"),
      shiny::textOutput(ns("clock")), table_view(ns("risk"))),
    panel("Absolute survival at the selected horizon", table_view(ns("fixed")),
      shiny::p("Survival is displayed as a percentage; treated minus control is displayed in percentage points. Intervals use facility resampling with PS refitting. No estimate is extended beyond follow-up support."),
      table_view(ns("support")), table_view(ns("bootstrap")), shiny::textOutput(ns("test"))))
}

survival_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$km <- shiny::renderPlot({
    shiny::req(result()); width <- session$clientData[[paste0("output_", session$ns("km"), "_width")]]
    plot_survival(result(), compact = isTRUE(width < 600))
  }, res = 110)
  output$clock <- shiny::renderText({
    r <- result(); shiny::req(r)
    sprintf("Time zero: day %d after diagnosis. Horizon: %g months after landmark (day %.1f after diagnosis). Observed at-risk counts are people; weighted risk mass is not a patient count.",
            r$preset$landmark_days, r$config$horizon_months, r$manifest$horizon_days_from_diagnosis)
  })
  output$risk <- shiny::renderTable({ shiny::req(result()); display_table(result()$risk) }, digits = 2)
  output$fixed <- shiny::renderTable({ shiny::req(result()); fixed_time_display(result()$fixed) }, digits = 4, na = "Withheld / not requested")
  output$support <- shiny::renderTable({ shiny::req(result()); display_table(result()$support) }, digits = 2)
  output$bootstrap <- shiny::renderTable({ shiny::req(result()); display_table(result()$bootstrap$audit) })
  output$test <- shiny::renderText({ shiny::req(result()); sprintf("Unweighted log-rank p = %.4g on the same complete-case sample. Weighted inference uses the clustered Cox Wald test on the Models tab.", result()$cox$unweighted_logrank_p) })
})

models_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(panel("Cox regression", shiny::plotOutput(ns("forest"), height = "300px"), table_view(ns("cox")),
      shiny::p("Covariate-adjusted HR is conditional; weighted treatment-only HR is a marginal working-model summary. These are not interchangeable estimands. Sandwich intervals condition on the fitted PS weights.")),
    panel("Proportional hazards diagnostic", table_view(ns("ph")),
      shiny::p("The Schoenfeld diagnostic is exploratory: its p value is not calibrated for facility clustering or PS estimation. If PH is questionable, emphasize survival probabilities rather than a constant HR.")),
    panel("Exploratory subgroup analysis", shiny::textOutput(ns("interaction")),
      shiny::plotOutput(ns("subforest"), height = "300px"), table_view(ns("subgroup")), table_view(ns("counts")),
      shiny::p("Estimates come from one pooled treatment × subgroup model with facility-clustered covariance. Global weights are retained. Sparse arms are suppressed. No multiplicity adjustment; interaction p tests heterogeneity directly.")))
}

models_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$forest <- shiny::renderPlot({ shiny::req(result()); plot_forest(result()$cox$table) }, res = 100)
  output$cox <- shiny::renderTable({ shiny::req(result()); display_table(format_p_column(result()$cox$table, "p_wald")) }, digits = 4)
  output$ph <- shiny::renderTable({ shiny::req(result()); display_table(format_p_column(result()$cox$ph, "p")) }, digits = 4)
  output$interaction <- shiny::renderText({
    r <- result(); shiny::req(r)
    sprintf("Subgroup: %s. Global robust Wald interaction p = %s. %s", variable_label(r$config$subgroup),
      if (is.na(r$subgroup$interaction_p)) "withheld" else format(r$subgroup$interaction_p, digits = 4), r$subgroup$status)
  })
  output$subforest <- shiny::renderPlot({ shiny::req(result()); plot_forest(result()$subgroup$table, "subgroup") }, res = 100)
  output$subgroup <- shiny::renderTable({ shiny::req(result()); display_table(result()$subgroup$table) }, digits = 4)
  output$counts <- shiny::renderTable({ shiny::req(result()); display_table(result()$subgroup$counts) }, digits = 2)
})

repro_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(panel("Reproduce this run", shiny::p("Every download describes the completed run, including its seed, design, estimand and sample sizes. Changing controls does not change these files until Run analysis is pressed."),
    shiny::downloadButton(ns("report"), "Analysis report (.html)"),
    shiny::downloadButton(ns("bundle"), "Download analysis bundle (.zip)"),
    shiny::downloadButton(ns("synthetic"), "Synthetic cohort (.csv)"),
    shiny::downloadButton(ns("manifest"), "Run manifest (.json)"),
    shiny::downloadButton(ns("figure"), "Survival figure (.pdf)"),
    shiny::verbatimTextOutput(ns("manifest_text"))),
    panel("Validation checkpoints", table_view(ns("qc"))),
    panel("Methods and provenance", shiny::p("All records are independently authored simulations. The generator does not fit to, resample from, or retrieve any registry records. The app accepts no uploaded data."),
      shiny::p("Designs are conditional landmark comparisons, not diagnosis-time target-trial emulations. Causal interpretation would require consistency, conditional exchangeability, positivity and appropriate censoring assumptions. No clinical or disparity finding follows from this demonstration."),
      shiny::p("Core and expanded models use complete cases, without imputing unknown treatment or survival. The expanded analysis changes both the adjustment set and eligible sample. See the repository audit and methods documents for source fidelity and scope.")))
}

repro_server <- function(id, result) shiny::moduleServer(id, function(input, output, session) {
  output$qc <- shiny::renderTable({ shiny::req(result()); display_table(result()$qc) })
  output$manifest_text <- shiny::renderText({ shiny::req(result()); jsonlite::toJSON(result()$manifest, auto_unbox = TRUE, pretty = TRUE, na = "null") })
  output$synthetic <- shiny::downloadHandler(filename = function() "synthetic_oncology.csv", content = function(file) {
    shiny::req(result()); utils::write.csv(result()$raw, file, row.names = FALSE)
  })
  output$manifest <- shiny::downloadHandler(filename = function() "run_manifest.json", content = function(file) {
    shiny::req(result()); jsonlite::write_json(result()$manifest, file, auto_unbox = TRUE, pretty = TRUE, na = "null")
  })
  output$figure <- shiny::downloadHandler(filename = function() "synthetic_survival.pdf", content = function(file) {
    shiny::req(result()); ggplot2::ggsave(file, plot_survival(result()), width = 9, height = 5.5, device = grDevices::cairo_pdf)
  })
  output$report <- shiny::downloadHandler(filename = function() "synthetic_analysis_report.html", content = function(file) {
    shiny::req(result()); write_analysis_report(result(), file)
  })
  output$bundle <- shiny::downloadHandler(filename = function() "synthetic_analysis_bundle.zip", content = function(file) {
    shiny::req(result()); folder <- tempfile("oncology-export-"); dir.create(folder)
    on.exit(unlink(folder, recursive = TRUE), add = TRUE)
    export_analysis(result(), folder, include_figures = TRUE)
    old <- setwd(folder); on.exit(setwd(old), add = TRUE)
    utils::zip(zipfile = file, files = list.files(folder), flags = "-q")
  })
})
