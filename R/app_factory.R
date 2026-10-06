create_app <- function() {
  ui <- shiny::fluidPage(title = "Oncology RWE Explorer",
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", type = "text/css", href = "style.css")),
    shiny::div(class = "app-header", shiny::div(class = "eyebrow", "RWE · ONCOLOGY · BIOSTATISTICS"),
      shiny::h1("Oncology RWE Explorer"),
      shiny::p("Interactive real-world oncology treatment-effect analysis platform"),
      shiny::span(class = "synthetic-badge", "100% SYNTHETIC DATA · EDUCATIONAL PORTFOLIO")),
    shiny::sidebarLayout(
      shiny::sidebarPanel(width = 3,
        shiny::h3("Study configuration"),
        shiny::actionButton("run", "Run analysis", class = "btn-primary run-button"),
        shiny::p(class="sidebar-footnote", "Applies all settings below to a new completed run."),
        shiny::selectInput("disease", "Disease / toy design", c("DLBCL: chemotherapy ± RT" = "DLBCL", "Extensive-stage SCLC: chemotherapy ± IO" = "SCLC")),
        shiny::uiOutput("design_note"),
        shiny::numericInput("n", "Synthetic records", 2500, min = 500, max = 10000, step = 500),
        shiny::numericInput("seed", "Simulation seed", 20261005, min = 1, max = 2e9, step = 1),
        shiny::selectInput("scenario", "Simulation scenario", c("Confounded comparison" = "standard", "No treatment effect" = "null", "Poor overlap stress test" = "poor_overlap", "Time-varying effect" = "non_ph")),
        shiny::sliderInput("missing_rate", "Baseline missingness parameter", min = 0, max = .3, value = .04, step = .01),
        shiny::selectInput("ps_spec", "Baseline adjustment set", c("Core / high retention" = "core", "Expanded / complete cases" = "expanded")),
        shiny::selectInput("method", "Analysis weighting", c("Stabilized IPTW / ATE" = "iptw", "Overlap weights / ATO" = "overlap", "Unweighted association" = "unweighted")),
        shiny::conditionalPanel("input.method == 'iptw'", shiny::checkboxInput("winsorize", "Sensitivity: winsorize weights at 1% / 99%", FALSE)),
        shiny::sliderInput("horizon_months", "Horizon: months AFTER landmark", min = 6, max = 60, value = 48, step = 6),
        shiny::selectInput("subgroup", "Exploratory subgroup", c("Sex" = "sex", "Age ≤60 / >60" = "age_group", "Simulated race/ethnicity" = "race_ethnicity")),
        shiny::selectInput("bootstrap_reps", "Facility bootstrap resamples", c("None / point estimates" = 0, "50 / quick demonstration" = 50, "200 / more stable intervals" = 200), selected = 50),
        shiny::p(class = "sidebar-footnote", "Baseline-only PS. Day-based landmark. All outcomes, demographics and facilities are fictional.")),
      shiny::mainPanel(width = 9,
        shiny::uiOutput("run_status"), shiny::uiOutput("analysis_header"), shiny::uiOutput("alerts"),
        shiny::tabsetPanel(id = "workspace",
          shiny::tabPanel("Overview", overview_ui("overview")),
          shiny::tabPanel("Cohort & Table 1", result_workspace(cohort_ui("cohort"))),
          shiny::tabPanel("Weighting & Balance", result_workspace(balance_ui("balance"))),
          shiny::tabPanel("Survival", result_workspace(survival_ui("survival"))),
          shiny::tabPanel("Models & Subgroups", result_workspace(models_ui("models"))),
          shiny::tabPanel("Reproducibility", result_workspace(repro_ui("repro")))))),
    shiny::div(class = "app-footer", if (grepl("wasm|emscripten", R.version$platform))
      "Synthetic demonstration • R computations run in your browser • No registry data or uploads" else
      "Synthetic demonstration • Reproducible R statistical engine • No registry data or uploads"))
  server <- function(input, output, session) {
    result <- shiny::reactiveVal(NULL)
    last_error <- shiny::reactiveVal(NULL)
    current_config <- shiny::reactive({
      cfg <- list(disease = input$disease, n = input$n, seed = input$seed, scenario = input$scenario,
        missing_rate = input$missing_rate, ps_spec = input$ps_spec, method = input$method,
        winsorize = isTRUE(input$winsorize) && identical(input$method, "iptw"),
        horizon_months = input$horizon_months, subgroup = input$subgroup,
        bootstrap_reps = as.integer(input$bootstrap_reps))
      cfg
    })
    shiny::observeEvent(input$disease, {
      shiny::updateSliderInput(session, "horizon_months", value = study_preset(input$disease)$horizon_months)
    }, ignoreInit = TRUE)
    output$design_note <- shiny::renderUI({
      shiny::req(input$disease); p <- study_preset(input$disease)
      shiny::p(class = "design-note", sprintf("Conditional day-%d landmark. %s", p$landmark_days,
        if (input$disease == "DLBCL") "Adult stage I–II; RT strictly after chemotherapy." else "Adult extensive-stage; IO on or after chemotherapy. New toy design."))
    })
    shiny::observeEvent(input$run, {
      cfg <- current_config()
      last_error(NULL)
      shiny::withProgress(message = "Simulating and validating oncology analysis", value = 0, {
        ans <- tryCatch(run_analysis(cfg, progress = function(value, detail) shiny::setProgress(value, detail = detail)), error = function(e) { last_error(conditionMessage(e)); NULL })
        if (!is.null(ans)) result(ans)
      })
    })
    output$run_status <- shiny::renderUI({
      if (!is.null(last_error())) return(shiny::div(class = "notice error", paste("Analysis failed:", last_error(),
        "Previous results, if shown, retain their previous configuration.")))
      if (is.null(result())) return(shiny::div(class = "notice", "Choose a synthetic study design and press Run analysis to begin."))
      if (!isTRUE(all.equal(current_config(), result()$config)))
        return(shiny::div(class = "notice", "Controls changed. Displayed results and downloads still describe the previous completed run. Press Run analysis to apply changes."))
      shiny::div(class = "notice success", "Analysis completed. Cohort, weighting, models and exports use one validated run configuration.")
    })
    output$analysis_header <- shiny::renderUI({
      r <- result(); shiny::req(r)
      shiny::div(class = "analysis-header", shiny::h2(paste(r$config$disease, "·", paste(r$preset$arms, collapse = " vs "))),
        shiny::p(estimand_label(r$config)),
        shiny::p(sprintf("Seed %d • %s PS • %g months after day-%d landmark • %d fictional facilities",
          r$config$seed, r$config$ps_spec, r$config$horizon_months, r$preset$landmark_days, length(unique(r$data$facility_id)))))
    })
    output$alerts <- shiny::renderUI({
      r <- result(); shiny::req(r)
      if (!length(r$alerts)) return(NULL)
      shiny::tags$details(class = "diagnostic-alerts", open = NA,
        shiny::tags$summary(paste("Statistical diagnostics:", length(r$alerts), "items")),
        shiny::tags$ul(lapply(r$alerts, shiny::tags$li)))
    })
    output$has_results <- shiny::renderText(if (is.null(result())) "FALSE" else "TRUE")
    shiny::outputOptions(output, "has_results", suspendWhenHidden = FALSE)
    overview_server("overview", result)
    cohort_server("cohort", result); balance_server("balance", result)
    survival_server("survival", result); models_server("models", result); repro_server("repro", result)
  }
  shiny::shinyApp(ui, server)
}
