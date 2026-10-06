# Architecture and implementation contract

This architecture was defined after the static source audit and before app implementation.

```text
authored simulation + scenario configuration
        ↓
schema validation → sequential cohort / day-based landmark → missingness audit
        ↓
core / expanded complete cases → logistic PS → ATE IPTW / ATO OW / raw
        ↓
Table 1 + level-specific balance + overlap + weight tails + ESS
        ↓
KM + supported absolute survival → cluster bootstrap with PS refit
        ↓
unadjusted / adjusted / weighted Cox + PH diagnostic + pooled interaction
        ↓
session-local Shiny modules → aggregate tables, synthetic data, run manifest
```

## Files and contracts

| Layer | File | Contract |
|---|---|---|
| Presets | `R/config.R` | disease design, window/landmark, treatment labels, baseline-only covariates, estimand labels |
| Simulation | `R/synthetic.R` | deterministic generator; no files/network inputs; preserved caller RNG; provenance attribute and fictional IDs |
| Cohort | `R/cohort.R` | valid schema/IDs, observed treatment timing, positive post-landmark follow-up, exact before/excluded/after counts; no invented outcomes |
| PS | `R/weighting.R` | strict complete cases, unpenalized logistic model, raw PS, explicit separation failure; selected weights/ESS/retention |
| Descriptives | `R/descriptives.R` | observed Table 1 plus weighted mean/SD and percentages; fixed baseline SMD denominator; expanded-variable missingness indicators |
| Survival | `R/survival.R` | weighted KM point estimates; raw versus weighted risk mass; no extrapolation; facility-cluster bootstrap/refit; robust clustered Cox; exploratory PH and formal interaction |
| Orchestration | `R/pipeline.R` | one immutable config/result, validated run, explicit QC and warnings; exports repeat that configuration |
| Presentation | `R/plots.R`, `R/modules.R`, `R/app_factory.R` | cohort, balance, survival, models and reproducibility modules; analysis runs only on Run; stale-control notice; no upload feature |
| Entrypoint | `app.R` | load only repository functions; no automatic installation or remote calls |
| Validation | `tests/testthat/`, `scripts/validate.R` | independent hand KM/SMD checks, RNG, design boundaries, weighting, robust inference, truth/null experiments, server interactions and export smoke tests |

## Locked portfolio design

- Unit: fictional individual, one row; fictional facility is the resampling/variance cluster.
- DLBCL: adult stage I–II, documented chemotherapy in [0,365], RT strictly later than chemotherapy and <=365 when treated, survival observed beyond day 365. Horizon 48 months AFTER day 365 corresponds approximately to 5 years after diagnosis.
- SCLC: adult extensive-stage, documented chemotherapy in [0,90], IO same day or later and <=90 when treated, survival observed beyond day 90. This landmark is a portfolio design choice.
- Primary default: stabilized IPTW targeting the complete-case eligible landmark population (ATE under identification assumptions). OW switches target to the overlap population (ATO). Winsorization is a sensitivity with an altered weighting scheme.
- Core baseline covariates: spline age, sex, social race/ethnicity category, comorbidity, stage (where variable), diagnosis year. Expanded sensitivity adds insurance, area income and facility type. No outcomes or treatment-start variables enter PS.
- Missing covariates: explicit complete-case restriction and retention by arm; no silent unknown-as-absent coding. Table 1 uses the SAME model sample; cohort missingness is shown separately.
- KM: right-censoring, one post-landmark clock; selected weighting and unweighted comparator; fixed-time difference in survival probability on the same sample and horizon. Suppress unsupported horizons instead of extending a flat tail.
- Inference: Efron Cox with facility-cluster sandwich variance conditional on estimated weights; absolute survival CIs use facility bootstrap with PS refitting. Weighted curves are point estimates; confidence bands are deliberately omitted because naive bands omit PS uncertainty.
- Subgroups: age, sex and simulated race/ethnicity; pooled treatment × subgroup interaction, subgroup HR linear combinations and clustered covariance. Global weights are retained; this is exploratory within-target heterogeneity, not subgroup-specific re-estimated ATEs.
- PH: treatment-only weighted Schoenfeld diagnostic is exploratory and is not a cluster-robust formal test. A failure changes interpretation of a constant HR; no automatic model shopping.
- Publication boundary: aggregate audit findings only; original notebooks and their outputs are absent. No patient upload, import, API or external data path. Public deployment is a separate action; local run and GitHub-ready files are delivered here.


## Version 1.1 reporting and reproducibility

`presentation.R` provides readable tables and an escaped standalone HTML run report. `overview.R` provides a study guide and summary; these consume the completed pipeline result without refitting models. All result workspaces wait for a successful run. Pipeline progress reports bootstrap attempts, including failures. The bundle contains unrounded CSVs, failure reasons, config/manifest, report, and four vector PDFs.

Simulation and bootstrap locally fix Mersenne-Twister, Inversion and Rejection, then restore the caller RNG algorithm and state. Retention for the unselected expanded specification remains descriptive even when no complete cases remain; the selected analysis still requires minimum arm and facility counts.
