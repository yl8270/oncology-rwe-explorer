# Source notebook audit

Scope: code-only static audit of four private Python notebooks. No cells were executed, no saved cell outputs or patient-level files were opened, and no original notebook is included in this repository. These findings concern the inspected implementations, not an independent validation of the original study results. Notebook comments were evidence, not instructions for this project.

## Source inventory and traceability

| Private source | Code cells / approximate code lines | Responsibilities retained |
|---|---:|---|
| 01 DLBCL preparation, v2.3.2 symmetric365 SES audit candidate | 15 / 3,191 | deterministic duplicate resolution, adult stage I–II cohort, symmetric treatment ascertainment, conditional landmark, sequential counts, SES provenance |
| 02 DLBCL main, v1.23.1 AJH refresh | 34 / 8,183 | Table 1, treatment-use summaries, high-retention versus expanded PS, stabilized IPTW, balance/ESS, KM, conventional and facility-clustered Cox, fixed-time absolute survival |
| 03 DLBCL advanced, v1.17.1 reviewer closure | 33 / 7,012 | formal interaction, PH diagnostics, start-stop time interaction, missingness/retention sensitivity, cluster bootstrap with PS refitting |
| SCLC Analysis_ESLS | 23 / 5,220 | pairwise treatment comparisons, binary IPTW/OW, balance, KM/Cox panels, IO timing, RMST and spline explorations |

Cell references below use the original zero-based notebook cell index.

## Preserve

- **01, cells 9–11:** documented chemotherapy within day 365 in both groups; treated patients additionally require confirmed external-beam RT after chemotherapy and by day 365. Unknown/nonqualifying RT is not automatically classified as no RT.
- **01, cells 5, 8, 10–14:** deterministic duplicates, year-to-SES-vintage provenance, sequential cohort flow, explicit validation. The new project starts with unique simulated identifiers and retains reconciliation assertions; no NCDB coding or private crosswalk is distributed.
- **02, cells 24–28:** a high-retention core PS model and an expanded complete-case sensitivity; treatment-specific retention and balance; stabilized IPTW plus separately labeled weight winsorization sensitivity.
- **02, cells 22, 24, 28; 03, cells 6–9, 40:** facility-clustered robust Cox and facility bootstrap, re-estimating PS in each bootstrap sample. R `survival` becomes the native engine.
- **03, cells 6–7, 14–20:** interaction tests rather than comparing subgroup significance; diagnose PH rather than treating convergence as sufficient validation.
- **SCLC, cells 6–9:** binary stabilized IPTW and binary overlap weights are useful complementary estimands.

## Corrections required for the public implementation

| Priority | Code evidence | Consequence | Implementation decision |
|---|---|---|---|
| Critical | SCLC cell 11, `_ensure_time_event_cols`: missing time/event filled with 0, negative time clipped; similar coercions recur in later cells | invents censoring/outcomes and hides invalid follow-up | exclude missing/invalid survival with explicit flow counts; never impute survival or jitter zeros |
| Major | SCLC cell 11, `overall_p` and triplet fit calls: weighted Cox without explicit robust variance, Cox p displayed as `logrank p` | replication-weight variance and mislabeled test | facility-clustered sandwich Cox; log-rank only for unweighted curves; distinct Wald labels |
| Major | SCLC cell 15, `add_multiclass_weights`: `1 - p_g` called overlap weight | binary formula does not generalize to K>2 arms | public app uses binary contrasts; generalized overlap weights require a separate implementation and validation |
| Major | 01 cell 11 uses follow-up >=12 months, retaining exact-boundary records; 02 fixed-time helpers use diagnosis time at 60 months; 03 Cox uses landmark time | boundary handling and “5-year” labels can be ambiguous | use one day-based clock; strictly positive follow-up after the landmark; horizon means months AFTER landmark, with diagnosis equivalent displayed |
| Major | 02/03 PS helper clips predicted PS to [0.01, 0.99]; weight clipping named “trimmed” | clipping changes weights and can conceal positivity failures | retain raw PS; fail numerical separation; display overlap; explicit optional 1st/99th percentile winsorization, no claim of unchanged ATE |
| Major | SCLC timing schemes define eventual IO timing groups but inspect diagnosis-based survival without a consistently explicit delayed-entry design | potential immortal-time bias; upstream staging/filtering code not supplied in this notebook | SCLC demo uses a declared 90-day landmark and same-day-or-later IO by day 90; this is a NEW toy design, not a source replication |
| Minor | SCLC categorical ASMD averages across levels; DLBCL SMD denominator recomputed under weighting | residual level-specific imbalance may be hidden; before/after denominator changes | report every category level using a fixed unweighted pooled SD on the selected complete-case sample, and expanded covariates as well as PS covariates |
| Major | notebooks rely on absolute paths, shared notebook globals, repeated helper definitions and broad warning suppression | order-dependent runs and portability problems | pure R functions, immutable run configuration, explicit model failures, namespaced Shiny modules, session-local results |

## Deliberate scope changes

The app is a **synthetic educational platform**, not reproduction of any source study. DLBCL uses an adult stage I–II day-365 landmark toy comparison (chemotherapy versus chemotherapy + RT). SCLC uses an adult extensive-stage day-90 landmark toy comparison (chemotherapy versus chemotherapy + IO). All demographics, outcomes, facility identifiers and missingness are independently simulated from authored distributions. Race/ethnicity is a simulated social covariate; no empirical disparity is inferred.

Original annual treatment-selection models, NCDB coding/vintages, dose reconstruction, multiclass timing comparisons, RCS and RMST are documented as source capabilities rather than exposed as unvalidated portfolio features. The required core workflow is implemented first. Conventional and weighted HRs have different interpretations; conditional generator HR truth is not used as a target for the marginal weighted HR. Landmark restriction changes the target population and does not establish a causal diagnosis-time treatment effect.

## Official implementation references

- [R survival: coxph](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/coxph.html): robust sampling-weight variance, cluster argument, Efron ties, convergence caveats.
- [R survival: survfit.formula](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.formula.html): weighted survival and variance.
- [Posit: Shiny modules](https://shiny.posit.co/r/articles/improve/modules/): namespaced UI/server modules.
