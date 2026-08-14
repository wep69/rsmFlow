# Dependency strategy: rsmFlow 0.2.0

## Core

`rsmFlow` imports only base/recommended R namespaces declared in `Imports`: `stats`, `graphics`, `grDevices`, and `utils`. The package never installs dependencies at load time and does not require network access for core analyses.

## Tier 1: classical design-aware RSM

Core OLS/WLS response-surface fitting, non-orthogonal-design audit, canonical analysis, bounded optimization, bootstrap infrastructure, near-optimal regions, economic optimum, and base graphics use core R. Optional interoperability/graphics:

- `rsm`: established CCD/BBD and RSM interoperability;
- `AlgDesign`: D-/I-optimal design generation;
- `ggplot2`: publication-oriented graphics;
- `plotly`: interactive graphics;
- `testthat`, `knitr`, `rmarkdown`: testing and vignette infrastructure.

## Tier 2: generalized and nonlinear response surfaces

- `MASS`: negative-binomial GLM-RSM and robust-regression sensitivity fits;
- `GA`: global response optimization and **genetic-algorithm search for nonlinear starting parameters**;
- `minpack.lm`: optional `nlsLM` backend for nonlinear least squares;
- `mco`: optional NSGA-II multiresponse search;
- `nloptr`: retained specialist optimizer/interoperability target.

`rsm_nonlinear_fit(start="ga")` uses the GA only to search parameter starting values. The selected final backend (`nlsLM`, `nls`, or `gnls`) performs the inferential fit. If `GA` is not installed, the start-search helper explicitly falls back to bounded random multistart and records the fallback.

## Tier 3: expert models

- `nlme`: `gnls` nonlinear mean structures with unequal-variance (`varPower`, `varExp`, or user-defined) and optional correlation structures;
- `DiceKriging`: Gaussian-process surrogate and expected-improvement recommendation;
- `mgcv`: GAM surfaces with main smooths plus pairwise tensor interactions, and joint multivariate thin-plate surrogates;
- `ranger`: random-forest surrogate;
- `nnet`: neural-network surrogate.

Tier 3 is opt-in. `rsmFlow` does not automatically replace a second-order response surface with a more flexible model based solely on AIC, RMSE, or one diagnostic.

## Specialist interoperability retained in Suggests

- `vdg`, `OptimaRegion`, `desirability2`.

The development version has native FDS/VDG summaries, bootstrap optimum regions, desirability, bounded optimization, and cross-engine decision tools. Direct adapters remain future interoperability work rather than hidden dependencies.
