# Statistical and simulation specification

## Data generation

`generate_synthetic()` uses only authored random distributions. IDs have `SYN-` prefixes; facilities have `SIM-` prefixes. Reproducibility uses a local seed while restoring the caller RNG state. Each dataset carries simulation provenance, including scenario and conditional HR. Exported CSVs have a `synthetic=TRUE` field; provenance JSON is separate. A synthetic flag alone is not a de-identification or privacy certification; the relevant guarantee is the generator's absence of empirical data inputs.

Covariates are fictional age, sex, social race/ethnicity category, comorbidity, stage, year, insurance, area income and facility type. Logistic treatment assignment depends on baseline covariates and a fictional facility treatment-preference perturbation. Facility preference does not enter the outcome model. Pre-landmark event hazard depends on baseline prognosis; treatment effect is applied only after the declared landmark. Censoring and administrative follow-up are independently generated. The common pre-landmark process ensures no true simulated treatment effect before ascertainment ends. These choices are software demonstrations, not oncology natural-history parameters.

Standard conditional post-landmark HRs are 0.72 (DLBCL) and 0.78 (SCLC). The null scenario HR is 1. The non-PH scenario has HR 0.50 during the first 365 days after landmark and 1.45 thereafter. The poor-overlap scenario strengthens treatment-selection dependence. Outcomes are generated independently for each fictional person conditional on covariates; facility clustering is retained to demonstrate robust inference/resampling. Missingness in baseline fields depends on observed age; treatment ascertainment and a small number of survival fields are independently made incomplete to exercise exclusions.

The source file itself is the complete operational DGP. The toy rates and exclusions were not estimated from original notebooks or datasets.

## Cohort and sample lineage

Apply disease, age, stage, confirmed treatment status, symmetric chemotherapy window, treated-arm adjunct sequence/window, valid time/event, treatment before observed exit, strict post-landmark follow-up, then complete baseline cases. Each step reports `N_before - N_excluded = N_after`. Pre-landmark disposition counts pertain to the sample after treatment and survival validation, not all generated records.

Use a single day clock. Post-landmark months equal `(exit_day - landmark_days) / (365.25 / 12)`. Exact landmark exit is excluded; no time jitter is used. The default DLBCL horizon is 48 post-landmark months, not 60. In contrast, the private source fixed-time helpers evaluated diagnosis month 60 within a landmark-selected sample; the public clock intentionally removes ambiguity.

Core/expanded retention is calculated on the eligible landmark sample. All descriptive and outcome outputs within a completed run use the chosen complete-case model sample. A core versus expanded run changes the sample and adjustment; it should not be interpreted as an isolated covariate-change experiment.

## Propensity scores and weights

Let `e(X)=Pr(A=1|X)`, fitted by unpenalized binomial GLM with natural spline age. Constant variables are omitted explicitly; convergence, rank deficiency, warnings or near-numerical separation cause failure. Raw predicted PS is displayed and never clipped.

Stabilized IPTW is `Pr(A=1)/e(X)` for treated and `Pr(A=0)/(1-e(X))` for controls. Binary OW is `1-e(X)` for treated and `e(X)` for controls. Raw comparison uses unit weights. IPTW winsorization uses pooled 1st/99th percentiles and caps weights without deleting rows. The manifest records actual cutoffs. ESS is `(sum(w)^2)/sum(w^2)` within each arm.

The overlap population is weighted toward treatment equipoise. It is a different target from ATE. Generalized K-arm OW and longitudinal treatment regimes are outside this release.

## Table 1 and balance

Raw continuous summaries use mean/sample SD; weighted continuous summaries use weighted mean/population second-moment SD. Categorical summaries show observed counts and nonmissing proportions; weighted columns show weighted proportions, not fabricated integer counts. Missing summaries use the full arm denominator.

SMD is treated minus control weighted means divided by the SAME unweighted pooled population second-moment SD from the model sample. Every categorical level is represented; missingness indicators are shown when missingness remains outside the fitted covariates. Age-spline bases are also audited. Numeric variable balance excludes missing values explicitly. Zero shared variance gives SMD 0 only when group means coincide; otherwise it is infinite. Diagnostics include expanded covariates even in a core model.

## Survival and inference

KM uses weighted product-limit estimation, right censoring, and post-landmark time. Raw and weighted curves use the same individuals. Observed at-risk counts, weight mass and risk-set ESS are separate quantities. Fixed-time survival requires observed support in both arms. Unsupported horizons return missing estimates and a visible diagnostic instead of carrying a flat KM tail indefinitely.

For requested intervals, draw the original number of facilities with replacement, retain all individuals from each draw, relabel drawn facilities/individual IDs, refit the PS and recompute selected weights and survival. Perform exactly B attempts, report failures, and require at least max(10, ceiling(0.8B)) successful attempts for percentile CIs. No failed replicate is quietly replaced. B=50 is a fast example; B=200 is the app's larger option. Resampling is on the fixed complete-case analysis sample, so uncertainty about the missing-data mechanism is not modeled.

Cox uses Efron ties and facility-cluster sandwich covariance. Unadjusted, conventional covariate-adjusted and selected-weight models all use the same complete-case sample. Weighted-model CIs condition on fitted weights; no claim of PS-refitted HR intervals is made. PH uses `cox.zph` as an exploratory diagnostic, without cluster-robust calibration. No automatic refitting is triggered by a p value. Unweighted log-rank is labeled separately from Cox Wald inference.

## Subgroups

Fit one `treatment * subgroup` weighted model. Estimate subgroup HRs by linear contrasts of the treatment and interaction coefficients; compute their variance using the full clustered covariance matrix. Test all interaction coefficients jointly using the robust Wald quadratic form. Subgroup models share one baseline hazard; separate-baseline subgroup fits need not match. Keep global PS weights, disclose the target, and suppress the whole interaction if any subgroup arm has fewer than 20 individuals, 5 events or ESS below 10. No multiplicity correction is applied; all subgroup output is exploratory.

## Limitations

This engine demonstrates measured-confounder methods, not sufficient causal identification. Landmark conditioning changes the target and can induce selection in real data; it does not recover diagnosis-time intention-to-treat effects. Complete-case restriction may cause selection bias. Residual confounding, dependent censoring, lack of overlap and PH violations require design-specific remedies. These are stated explicitly rather than disguised by successful model convergence.

See [coxph](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/coxph.html) and [survfit](https://stat.ethz.ch/R-manual/R-devel/library/survival/html/survfit.formula.html) for the statistical software implementation.


## Version 1.1 reporting and reproducibility

`presentation.R` provides readable tables and an escaped standalone HTML run report. `overview.R` provides a study guide and summary; these consume the completed pipeline result without refitting models. All result workspaces wait for a successful run. Pipeline progress reports bootstrap attempts, including failures. The bundle contains unrounded CSVs, failure reasons, config/manifest, report, and four vector PDFs.

Simulation and bootstrap locally fix Mersenne-Twister, Inversion and Rejection, then restore the caller RNG algorithm and state. Retention for the unselected expanded specification remains descriptive even when no complete cases remain; the selected analysis still requires minimum arm and facility counts.
