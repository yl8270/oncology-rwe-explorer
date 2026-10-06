# Public demo deployment

Live URL: https://yl8270.github.io/oncology-rwe-explorer/

The site uses official Posit Shinylive to run R Shiny through WebR in the visitor's browser. GitHub Pages serves static files. No external R server, patient-data upload, or new account is required. First use downloads the R runtime and compiled packages; analysis time depends on the client device. The app generates fully fictional data locally within its R runtime. It makes no registry-data requests.

## Build and publish

From the repository root, with R installed:

```sh
Rscript scripts/install_dependencies.R
Rscript -e 'install.packages("shinylive", repos="https://cloud.r-project.org")'
Rscript scripts/validate.R
Rscript scripts/build_site.R
```

The builder stages only `app.R`, public `R/*.R`, and `www/style.css`. It excludes notebooks, datasets, local outputs and Git files. The generated website is written to ignored `outputs/site/`; do not commit its runtime binaries. The tested builder is shinylive 0.5.0 with assets pinned to 0.10.12. WebAssembly packages are fetched at build time; their versions are recorded in the completed-run manifest. Assets are pinned, but this is not an immutable lock of every transitive package.

The GitHub Pages setting uses **GitHub Actions**. A push to `main` runs `.github/workflows/deploy-pages.yml`: install dependencies, test the engine and portable exports, build the site, upload a Pages artifact, and deploy. Statistical simulation validation also runs in the separate validation workflow. The deployment job uses narrowly scoped Pages write and OIDC permissions.

## Runtime and export details

The native validated environment uses R 4.4.3. The current browser assets provide R 4.6.0; consult the manifest for actual package versions. No bitwise equality across these environments is promised. The statistical code and cohort/estimand definitions are unchanged. Native and browser default DLBCL cohort counts and displayed Cox results were compared.

ZIP creation uses `zip::zipr`, avoiding a shell command unsupported in browser R. PDF output uses Cairo where available and the base R vector PDF device otherwise. Browser downloads require the browser to permit file downloads. Completed results live in the current browser session; save a config or bundle to replay a run before closing or reloading. Download delivery is a browser integration behavior distinct from native bundle validation.

Prefer a current desktop browser for the portfolio walkthrough. Start with the default sample and bootstrap count; large cohorts or hundreds of resamples can be slow on memory-constrained devices. A browser run may fail explicitly for unsupported stress scenarios or non-estimable models, just as the native engine does. The native command-line workflow remains available for reproducible batch analysis.

Official references: [R Shinylive](https://posit-dev.github.io/r-shinylive/), [export API](https://posit-dev.github.io/r-shinylive/reference/export.html), [WebR](https://docs.r-wasm.org/webr/latest/).
