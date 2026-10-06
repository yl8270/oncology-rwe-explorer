# Portfolio and resume copy

## Project title

**Oncology RWE Explorer — Interactive Treatment-Effect Analysis Platform**

## Resume bullets

- Built a modular R Shiny platform for oncology real-world evidence workflows using fully synthetic DLBCL and SCLC cohorts, integrating cohort lineage, Table 1, propensity-score weighting, balance diagnostics, Kaplan–Meier analysis, Cox regression and exploratory subgroup interactions.
- Implemented stabilized IPTW and overlap weighting with explicit ATE/ATO targets, treatment-specific complete-case retention, effective sample size, facility-clustered Cox inference and PS-refitted cluster bootstrap intervals for absolute survival differences.
- Refactored four notebook workflows into a reproducible statistical engine with automated design-boundary and estimator checks, session-specific run manifests, downloadable analysis bundles and an independently authored synthetic generator and standalone HTML/vector-PDF reporting.

## Concise version

Developed an R Shiny oncology treatment-effect analysis portfolio with synthetic data, PS weighting, survival modeling, subgroup interactions and reproducible statistical QC.

## GitHub repository description

Interactive oncology RWE analysis in R Shiny: synthetic cohorts, IPTW/overlap weighting, balance diagnostics, survival analysis and reproducible QC.

Suggested repository name: `oncology-rwe-explorer`.
Suggested topics: `r`, `shiny`, `biostatistics`, `real-world-evidence`, `oncology`, `survival-analysis`, `propensity-score`, `synthetic-data`.

## Interview explanation

“I started by auditing the study definitions and statistical implementations in four oncology notebooks. I separated reusable analysis components from study-specific registry logic, corrected outcome coercion and weighted-inference issues, then implemented a modular R engine with a Shiny interface. The demo uses independently generated fictional patients only. The key design decisions were explicit landmark time zero, separate ATE and ATO targets, consistent analytic denominators, overlap and retention diagnostics, and reproducible exports. The platform demonstrates my statistical judgment and software workflow; its simulated results are not clinical evidence.”

## 中文项目介绍

将四个 oncology/RWE notebook 的核心统计流程重构为模块化 R Shiny 平台，使用完全独立生成的 synthetic cohorts，整合 cohort flow、Table 1、IPTW/overlap weighting、balance/ESS、KM、facility-clustered Cox 与正式 subgroup interaction。项目强调时间零点、estimand、缺失样本保留率及可复现 QC，支持带 seed/config 的分析导出。

Do not add claims of public deployment, real patient counts, performance improvements or clinical findings unless those have actually been established.
