# Changelog

## 1.1.0

- Added an Overview workspace with declared designs, estimands, workflow and completed-run summary.
- Moved Run analysis to the first visible configuration controls; added intentional pre-run empty states and bootstrap progress.
- Improved table labels and survival percentages / percentage-point contrasts without rounding exported CSVs.
- Added escaped standalone HTML reports and four vector PDFs to the reproducibility bundle.
- Recorded attempted bootstrap resamples and individual failure reasons.
- Fixed simulation RNG algorithms locally while preserving caller RNG state, including an absent seed.
- Allowed unselected expanded retention summaries to report an empty sample without aborting a valid core analysis. Selected analyses retain their sample checks.
- Added focused statistical, reproducibility and report-export regression checks.

## 1.0.0

Initial synthetic-only portfolio rebuild after a code-only audit of four private oncology notebooks.
