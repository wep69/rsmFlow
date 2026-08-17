# rsmFlow 0.2.0

`rsmFlow` is a design-aware response-surface workflow for teaching and advanced scientific use. Classical polynomial RSM supports **two or more quantitative factors**; the new generalized-linear and nonlinear modules focus on **two quantitative factors**. Mixture experiments are deliberately excluded.

## Installation

### From GitHub (recommended)

```r
# install.packages("remotes")
remotes::install_github("wep69/rsmFlow")
```

### Without vignettes (faster install)

```r
remotes::install_github("wep69/rsmFlow", build_vignettes = FALSE)
```

### With vignettes

```r
remotes::install_github("wep69/rsmFlow", build_vignettes = TRUE)
```

### From local source

```r
# Download the tarball from the releases page, then:
install.packages("rsmFlow_0.2.0.tar.gz", repos = NULL, type = "source")
```

## Vignettes

The 11 vignettes are available for separate download:

| # | Vignette | Description |
|---|----------|-------------|
| 00 | [Getting started](vignettes_html/.html) | Overview and basic workflow |
| 01 | [Non-orthogonal designs](vignettes_html/.html) | Design audit and diagnostics |
| 02 | [Optimization & uncertainty](vignettes_html/.html) | Optimization with confidence intervals |
| 03 | [Multi-response economics](vignettes_html/.html) | Desirability and Pareto analysis |
| 04 | [Graphics & teaching](vignettes_html/.html) | Static and interactive plots |
| 05 | [Advanced surrogates](vignettes_html/.html) | GP, GAM, RF, NN surrogates |
| 06 | [GLM response surfaces](vignettes_html/.html) | Two-factor GLM-RSM |
| 07 | [Nonlinear response surfaces](vignettes_html/.html) | Two-factor nonlinear models |
| 08 | [Tier-3 integrated](vignettes/08-tier3-integrated.html) | Advanced model integration |
| 09 | [Engine comparison](vignettes_html/.html) | Comparing fitting engines |
| 10 | [State of the art](vignettes_html/.html) | Comprehensive tutorial |

## Cheatsheets

| Cheatsheet | Description | Download |
|------------|-------------|----------|
| [rsmFlow Cheatsheet EN](https://github.com/wep69/rsmFlow/releases/download/v0.2.0/rsmFlow_Cheatsheet_EN.pdf) | Single-page quick reference | [PDF](https://github.com/wep69/rsmFlow/releases/download/v0.2.0/rsmFlow_Cheatsheet_EN.pdf) |
| [rsmFlow Cheatsheet 10 pages](https://github.com/wep69/rsmFlow/releases/download/v0.2.0/rsmFlow_Cheatsheet_10pages_EN_Image20.pdf) | Extended 10-page reference with examples | [PDF](https://github.com/wep69/rsmFlow/releases/download/v0.2.0/rsmFlow_Cheatsheet_10pages_EN_Image20.pdf) |

## What is integrated

1. CCD, Box-Behnken, custom, D-/I-optimal design entry points.
2. Non-orthogonal/imperfect-design audit: estimability, conditioning, VIF, term correlation, prediction variance, FDS/VDG, rotatability proxies, alias information, and design augmentation.
3. Hierarchical Gaussian first-/second-order RSM for two or more factors.
4. **Two-factor GLM-RSM**: Gaussian, Poisson, quasi-Poisson, binomial, quasi-binomial, Gamma, inverse-Gaussian, and optional negative-binomial models.
5. **Two-factor nonlinear surfaces**: Mitscherlich, Gompertz, Michaelis-Menten, asymptotic, Hoerl, linear plateau, quadratic plateau, and custom formulas.
6. **GA parameter initialization** for nonlinear regression, with bounded multistart fallback and explicit user starts.
7. Optional `nlsLM`, base `nls`, and Tier-3 `gnls` backends.
8. Canonical/sequential polynomial RSM; response-scale canonical classification for second-order GLMs.
9. Bounded grid/L-BFGS-B/GA/hybrid optimization.
10. Model-aware optimum uncertainty: parametric refit bootstrap for likelihood GLMs and homoscedastic nonlinear fits, coefficient simulation for quasi-GLM/gnls, residual bootstrap for classical OLS, plus explicitly cautioned case bootstrap.
11. Near-optimal regions, optimum stability, uncertainty-aware optimization.
12. Multiple-response desirability, weighted/distance/epsilon compromises and Pareto/NSGA-II.
13. Economic optimum alongside biological optimum for compatible model classes.
14. Tier-3 GP, GAM/TPS, random forest, neural network and one-step Bayesian optimization.
15. Static and interactive surfaces, contours, heat maps, profiles, perturbation plots, slices and design-specific diagnostics.

## Unified fitting examples

### Classical RSM

```r
fit <- rsm_fit(dat, "Yield", c("N","K","Irrigation"), order=2)
rsm_design_audit(fit)
rsm_optimize(fit, "max", "hybrid")
```

### GLM-RSM

```r
fit_count <- rsm_fit(dat_count, "Insects", c("Dose","Days"),
                     engine="glm", family=poisson())
rsm_glm_dispersion(fit_count)
rsm_optimize(fit_count, "min", "L-BFGS-B")
```

### Nonlinear surface with GA initial values

```r
fit_nl <- rsm_nonlinear_fit(dat_nutrient, "Yield", c("N","P"),
                            model="mitscherlich2_product",
                            start="ga", engine="nlsLM")
rsm_nonlinear_diagnostics(fit_nl)
rsm_optimize(fit_nl, "max", "hybrid")
```

## Tier 3

```r
# Gaussian process + one-step expected improvement
fit_gp <- rsm_surrogate(dat, "Yield", c("x1","x2"), method="gp")
next_run <- rsm_bayes_opt(dat, "Yield", c("x1","x2"))

# Nonlinear generalized least squares
fit_gnls <- rsm_nonlinear_fit(dat_nutrient, "Yield", c("N","P"),
                              model="mitscherlich2_product",
                              start="ga", engine="gnls", variance="power")
```

Tier 3 is never selected automatically solely because it gives a lower error or AIC. Scientific compatibility, design, convergence, diagnostics, prediction and optimum stability remain part of model assessment.

## Validation status

- **0 ERRORs** on win-builder (R-devel + R-release) and macbuilder (R 4.6.1)
- 2 WARNINGs (documentation only: missing `...` in roxygen, duplicated Rd arguments)
- All testthat tests pass on all platforms
- All 11 vignettes render successfully

## Authors

- **Walter Esfrain Pereira** ([ORCID](https://orcid.org/0000-0003-1085-0191)) — author, maintainer, copyright holder
- **Magali Haidee Pereira Martinez** ([ORCID](https://orcid.org/0009-0009-5419-959X)) — author

## License

MIT
