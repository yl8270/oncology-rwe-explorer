# Local validation report

Validated with R 4.4.3; exact package versions are in `package_versions.json`. Every dataset below was produced by the public synthetic generator. No original notebook was executed and no patient-level NCDB file was opened.

## Automated checks

`Rscript scripts/validate.R`: **19 test groups, 113 assertions passed; 0 failures, 0 errors, 0 warnings, 0 skipped tests.**

- Deterministic generator, fictional IDs and caller RNG algorithm/state restoration, including an initially absent seed.
- Strict landmark boundary, symmetric chemotherapy window, correct adjunct ordering and valid event coding. SCLC same-day IO rule checked separately.
- Missingness and treatment-specific complete-case retention reconcile to the analytic sample.
- Weighted KM independently agrees with a hand-calculated tied risk-set example.
- SMD independently agrees with known before/after values using one fixed denominator.
- Binary IPTW/OW formulas agree with direct arithmetic; unpenalized OW balances fitted features within numerical tolerance.
- Clustered Cox coefficient and sandwich variance are invariant to global weight scaling.
- Unsupported survival horizons and sparse subgroup arms withhold estimates.
- Bootstrap repeatability, success/failure counts, PS refitting path and RNG preservation.
- Pooled subgroup coefficients and robust interaction p agree with direct covariance contrasts.
- Both diseases × all three weighting choices; null, poor-overlap and non-PH stress scenarios; explicit winsorization sensitivity.
- Synthetic exports reproduce run configuration and provenance. Escaped HTML report and four vector PDF signatures checked; unrounded estimates retained.
- Shiny server run, Overview summary rendering, stale controls, subsequent rerun, and invalid-input failure preserve completed-run consistency.

## Independent simulation checks

`Rscript scripts/validate_simulation.R`: **48 independent synthetic cohorts**, 6,000 generated individuals per cohort, 12 seeds in each disease × standard/null combination, expanded complete-case adjustment. These are bounded sanity checks rather than a coverage, type-I-error or power study.

| Disease / scenario | Conditional generating HR | Geometric mean adjusted HR | Geometric mean crude HR | Geometric mean weighted HR |
|---|---:|---:|---:|---:|
| DLBCL / standard | 0.720 | 0.723 | 0.598 | 0.734 |
| SCLC / standard | 0.780 | 0.785 | 0.657 | 0.800 |
| DLBCL / null | 1.000 | 1.009 | 0.820 | 1.004 |
| SCLC / null | 1.000 | 1.008 | 0.821 | 0.997 |

Adjusted mean log-HR errors were below the prespecified 0.10 tolerance and improved upon crude confounding bias. Weighted HRs are intentionally not tested against conditional truth because they estimate a different working-model summary. The full replicate and summary CSVs are produced under `outputs/validation/` when the script is run.

## Browser and export checks

- The app served successfully on a loopback-only Shiny server and rendered in the Codex in-app browser.
- A completed default DLBCL run reported 2,500 generated → 1,580 landmark eligible → 1,564 model individuals, 707 observed deaths and 60 fictional facilities; all five displayed QC checks passed.
- Default facility bootstrap: 50 requested, 50 attempted, 50 successful, 0 failures. Forced-failure fixtures record all 10 attempts and reasons and withhold CIs.
- Cohort/Table 1, propensity/weight distributions, Cox forest, conditional survival curves/risk tables and reproducibility controls were inspected. Desktop and narrow browser layouts render with responsive columns and horizontal table scrolling. Final Overview and Survival previews are saved as `preview-overview.jpg` and `preview-survival.jpg`.
- The browser-downloaded analysis ZIP opened successfully with **24 files** in the original 1.0.0 check; version 1.1.0 command-line export has **30 files**, including the HTML report, bootstrap failure audit and four PDFs. Its manifest, cohort and synthetic CSV reproduced the displayed seed and denominators; generated CSV had exactly 2,500 data rows. Browser downloads are additional local copies; the distributable source archive is assembled separately.
- Command-line example exported all tables, escaped standalone report and survival/balance/PS/Cox vector PDFs. The public app does not need these generated outputs to start.

## Interpretation boundaries

The default core PS intentionally leaves some expanded-variable imbalance visible. This is not hidden by a green “model ran” status: diagnostics state residual SMD and the complete-case target. Bootstrap B=50 is labeled a quick demonstration. Survival curves omit naive weighted confidence bands; fixed-time CIs refit the PS. Clustered Cox CIs condition on the fitted weights. PH p values remain exploratory and uncalibrated for cluster/PS uncertainty. SCLC's 90-day landmark is a newly declared demonstration design.

The GitHub CI workflow validates R 4.4.3 and the current release on Ubuntu. Remote CI status is shown in the repository Actions tab. Local results above are independently verified; remote CI success is claimed only after its completed run. No hosted Shiny service is deployed.
