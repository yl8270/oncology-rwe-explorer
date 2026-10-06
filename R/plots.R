vector_pdf_device <- function() {
  if (isTRUE(capabilities("cairo"))) grDevices::cairo_pdf else grDevices::pdf
}

plot_theme <- function() ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), plot.title = ggplot2::element_text(face = "bold"),
                 legend.position = "bottom")

plot_balance <- function(result) {
  d <- result$balance
  d$covariate <- variable_label(d$covariate)
  out <- rbind(data.frame(covariate = d$covariate, smd = d$abs_unweighted, version = "Before weighting"),
               data.frame(covariate = d$covariate, smd = d$abs_weighted, version = "Selected weights"))
  out$covariate <- factor(out$covariate, levels = rev(unique(d$covariate)))
  ggplot2::ggplot(out, ggplot2::aes(smd, covariate, color = version, shape = version)) +
    ggplot2::geom_vline(xintercept = .1, linetype = 2, color = "grey50") +
    ggplot2::geom_point(size = 2.4, na.rm = TRUE) + ggplot2::scale_color_manual(values = c("#9B9B9B", "#007F86")) +
    ggplot2::labs(x = "Absolute standardized mean difference", y = NULL, color = NULL, shape = NULL,
      title = "Covariate balance", subtitle = "Same model sample; fixed unweighted pooled SD. All levels shown.") + plot_theme()
}

plot_ps <- function(result) {
  ggplot2::ggplot(result$data, ggplot2::aes(ps, fill = treatment_label)) +
    ggplot2::geom_histogram(position = "identity", bins = 30, alpha = .55) +
    ggplot2::scale_fill_manual(values = c("#2D536E", "#00898B")) +
    ggplot2::labs(x = "Raw estimated propensity score", y = "Observed individuals", fill = NULL,
                  title = "Propensity-score overlap") + plot_theme()
}

plot_weights <- function(result) {
  ggplot2::ggplot(result$data, ggplot2::aes(weight, fill = treatment_label)) +
    ggplot2::geom_histogram(bins = 35, alpha = .65, position = "identity") +
    ggplot2::scale_fill_manual(values = c("#2D536E", "#00898B")) +
    ggplot2::labs(x = "Selected analysis weight", y = "Observed individuals", fill = NULL,
                  title = "Weight distribution") + plot_theme()
}

plot_survival <- function(result, compact = FALSE) {
  selected <- result$km; selected$version <- weighting_label(result$config)
  raw <- result$raw_km; raw$version <- "Unweighted"
  d <- if (result$config$method == "unweighted") raw else rbind(selected, raw); d <- d[order(d$arm, d$version, d$time), ]
  plot <- ggplot2::ggplot(d, ggplot2::aes(time, survival, color = arm, linetype = version)) +
    ggplot2::geom_step(linewidth = .9) +
    ggplot2::geom_vline(xintercept = result$config$horizon_months, color = "grey60", linetype = 3) +
    ggplot2::scale_color_manual(values = c("#2D536E", "#00898B")) +
    ggplot2::scale_y_continuous(limits = c(0,1), labels = function(x) paste0(round(100*x), "%")) +
    ggplot2::coord_cartesian(xlim = c(0, min(72, max(d$time)))) +
    ggplot2::labs(x = "Months after landmark", y = "Overall survival probability", color = NULL, linetype = NULL,
      title = if (compact) "Landmark survival" else "Conditional overall survival",
      subtitle = if (compact) "Point estimates; no naive
weighted confidence bands" else "Point estimates; no naive weighted confidence bands") + plot_theme()
  if (compact) plot <- plot + ggplot2::guides(color = ggplot2::guide_legend(ncol=1), linetype = ggplot2::guide_legend(ncol=1)) +
    ggplot2::theme(legend.box="vertical", legend.text=ggplot2::element_text(size=10), plot.subtitle=ggplot2::element_text(size=10))
  plot
}

plot_forest <- function(table, label_col = "model") {
  d <- table; d$label <- d[[label_col]]
  d <- d[is.finite(d$hr) & is.finite(d$lower_95) & is.finite(d$upper_95), ]
  if (!nrow(d)) return(ggplot2::ggplot() + ggplot2::annotate("text", x = 0, y = 0, label = "Estimates withheld: sparse or non-estimable") + ggplot2::theme_void())
  d$label <- factor(d$label, levels = rev(unique(d$label)))
  ggplot2::ggplot(d, ggplot2::aes(hr, label)) +
    ggplot2::geom_vline(xintercept = 1, linetype = 2, color = "grey50") +
    ggplot2::geom_segment(ggplot2::aes(x = lower_95, xend = upper_95, yend = label), color = "#007F86") +
    ggplot2::geom_point(size = 3, color = "#007F86") + ggplot2::scale_x_log10() +
    ggplot2::labs(x = "Hazard ratio (95% facility-cluster interval)", y = NULL) + plot_theme()
}
