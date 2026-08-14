# rsmFlow 0.2.0: implementation report

**Build date:** 2026-08-13  
**Project mode:** major extension of the design-aware RSM package extracted from the supplied Shiny application  
**Mixture experiments:** excluded by design

## Structured build state

```text
project_language: R
package_name: rsmFlow
package_version: 0.2.0
project_mode: extend + refactor + document
architecture_status: implemented
implementation_status: source-complete for requested 0.2.0 modules
documentation_status: updated; runtime rendering pending
test_status: tests written; execution pending
runtime_validation_status: pending (R/Rscript unavailable in build environment)
release_status: development source snapshot, not CRAN-certified
```

## 1. Classical design-aware RSM retained

The 0.1.0 core remains available: hierarchical first-/second-order polynomial RSM for two or more quantitative factors, non-orthogonal design audit, FDS/VDG, design augmentation, canonical/sequential analyses, bounded/GA/hybrid optimization, optimum uncertainty, multiple responses, graphics, and economic optimum.

## 2. New two-factor GLM-RSM module

Implemented `rsm_glm_fit()` and unified `rsm_fit(engine="glm")` routing for exactly two quantitative factors. Supported families are:

- Gaussian;
- Poisson and quasi-Poisson;
- binomial and quasi-binomial, including proportion responses with prior trial weights;
- Gamma;
- inverse Gaussian;
- optional negative binomial through `MASS::glm.nb()`.

Additional functions:

- `rsm_glm_dispersion()`;
- `rsm_glm_diagnostics()`;
- `rsm_glm_lack_of_fit()` using a replicated cell-means generalized reference model;
- `rsm_glm_canonical()` with stationary candidate from the link-scale polynomial and maximum/minimum/saddle classification checked numerically on the response scale.

Prior weights are retained inside the fitted rsmFlow object so binomial/trial-weight structure can be preserved during cross-validation, refitting and bootstrap workflows.

## 3. New two-factor nonlinear response-surface module

Implemented `rsm_nonlinear_fit()` with the built-in registry returned by `rsm_nonlinear_models()`:

- Mitscherlich product;
- Mitscherlich with offsets;
- Gompertz product;
- Michaelis-Menten product;
- additive asymptotic response;
- Hoerl;
- linear plateau;
- quadratic plateau;
- custom nonlinear formula.

Final fitting backends:

- optional `minpack.lm::nlsLM`;
- base `stats::nls` with PORT bounds;
- Tier-3 `nlme::gnls` with optional variance/correlation structures.

The `gnls` interface does not silently reinterpret ordinary observation weights as a variance model; heteroscedasticity must be declared through `variance=`.

## 4. GA starting-parameter search

Implemented `rsm_nonlinear_start_ga()` and integrated `start="ga"` into `rsm_nonlinear_fit()`.

Workflow:

```text
scientifically declared nonlinear equation
        -> finite named parameter bounds
        -> GA minimization of weighted SSE
        -> best parameter vector
        -> nlsLM / nls / gnls final estimation
        -> convergence and identifiability diagnostics
```

GA therefore supplies initialization and does not replace the inferential estimator. `start="multistart"` remains available, and `start="ga"` falls back transparently to bounded random multistart when the optional `GA` package is unavailable. The chosen start engine, starting vector and start-search SSE are retained in the fitted object.

## 5. Nonlinear diagnostics

`rsm_nonlinear_diagnostics()` reports:

- backend convergence status;
- coefficients;
- RSS and RMSE;
- log-likelihood/AIC/BIC when defined by the backend;
- numerical prediction-Jacobian singular values;
- local Jacobian condition number;
- parameter covariance/correlation when available;
- start-search engine and SSE;
- weak-identifiability warning.

## 6. Unified model abstraction

The decision/prediction layer now recognizes four classes:

- `rsmFlow_fit`;
- `rsmFlow_glm`;
- `rsmFlow_nonlinear`;
- `rsmFlow_surrogate`.

The common API now supports, where mathematically meaningful:

- response prediction;
- `rsm_optimize()` with grid, L-BFGS-B, GA and hybrid strategies;
- `rsm_optimum_ci()` with model-aware refitting and reoptimization;
- `rsm_near_optimal()`;
- `rsm_robust_optimize()` when prediction uncertainty is available;
- `rsm_economic_optimum()`;
- response profiles and perturbation plots;
- surface/contour/heatmap/interactive graphics;
- cross-validation for refittable Gaussian, GLM and nonlinear classes;
- cross-engine and cross-optimum comparison.

Likelihood-based GLMs and homoscedastic `nls`/`nlsLM` fits use parametric refit-and-reoptimization as the default optimum-uncertainty pathway. Quasi-family GLMs and `gnls` fits use asymptotic coefficient simulation in this development version because a unique full response-simulation law (quasi families) or a complete variance/correlation-aware simulator (`gnls`) is not assumed. Residual bootstrap remains the default for classical Gaussian OLS. Case bootstrap is explicitly labeled as a sensitivity procedure because it can disrupt experimental-design structure.

## 7. Tier 3 fully integrated

Tier 3 remains explicit and expert-only:

- `nlme::gnls` for nonlinear mean functions with heterogeneous/correlated errors;
- Gaussian process via `DiceKriging`;
- GAM models with main smooths plus pairwise tensor interactions, and joint thin-plate surfaces via `mgcv`;
- random forest via `ranger`;
- neural network via `nnet`;
- one-step expected-improvement Bayesian optimization.

Bayesian optimization proposes only the next candidate experimental point. It does not fabricate the unobserved response or continue automatically without new observed data.

## 8. Comparison framework

Added:

- `rsm_compare_engines()` for compatible RMSE/MAE/logLik/AIC/BIC/convergence summaries;
- `rsm_compare_optima()` for factor coordinates, predictions and optimization method.

Ordinary AIC/BIC are not used for quasi-family ranking. Model choice remains based on scientific compatibility, design, convergence, diagnostics, prediction and optimum stability rather than a single fit statistic.

## 9. Shiny layer

The thin Shiny application now exposes:

- Gaussian polynomial RSM;
- GLM-RSM family selection;
- nonlinear built-in models with GA or multistart initialization;
- `nlsLM`, `nls`, or Tier-3 `gnls` backends;
- GP/GAM-TPS/random-forest/neural-network Tier-3 surrogates;
- unified bounded/GA/hybrid optimization and contour output.

The Shiny application contains no separate statistical implementation; it calls the public package API.

## 10. Documentation

The package now has 11 vignettes. New 0.2.0 vignettes are:

1. `06-glm-response-surfaces.Rmd`;
2. `07-nonlinear-response-surfaces.Rmd`;
3. `08-tier3-integrated.Rmd`;
4. `09-engine-comparison.Rmd`;
5. `10-state-of-the-art.Rmd`.

Each new major module contains three worked examples. Manuals were expanded for GLM-RSM, nonlinear surfaces, Tier 3, unified fitting, optimization, plotting, economics and model comparison.

## 11. Tests and frozen simulations

New test groups cover:

- Poisson, weighted-binomial, Gamma and optional negative-binomial GLM-RSM;
- nonlinear explicit-start, multistart, GA-start and `gnls` pathways;
- common API routing;
- economic/near-optimal nonlinear decisions;
- Tier-3 GAM, joint TPS, GP/Bayesian optimization, random forest and neural network;
- cross-engine summaries.

The frozen simulation battery adds scenarios J-N for GLM family recovery, nonlinear parameter recovery/convergence, GA versus random-multistart initialization, conditional GAM/TPS/GP/random-forest/neural-network benchmarks, and `gnls` under response-dependent heteroscedasticity. No quantitative claims are made until those simulations are executed in R.

## 12. Static inventory

Current source inventory:

- 53 exported functions;
- 23 registered S3 methods;
- 18 R source files;
- 15 Rd manual files;
- 11 R Markdown vignettes;
- 9 testthat files;
- 3 R validation/simulation scripts plus a Windows wrapper.

Static checks found no missing exported implementation, duplicate top-level function definition, missing Rd alias, missing S3 implementation, or unbalanced source delimiters.

## 13. Release gate

This build environment does not contain R/Rscript. Therefore the following remain pending and must not be represented as completed:

- loading the package in R;
- executing examples and testthat;
- numerical tolerance/coverage validation;
- rendering all vignettes;
- optional-backend runtime interoperability;
- canonical `R CMD build` source creation;
- `R CMD check --as-cran`.

Use `scripts/VALIDATE_AND_BUILD.R` or the supplied PowerShell wrapper locally. The frozen simulation battery should be executed only after the runtime package gate passes.
