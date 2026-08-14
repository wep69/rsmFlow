# rsmFlow 0.2.0

* Added two-factor GLM response surfaces through `rsm_glm_fit()` and unified `rsm_fit(engine="glm")` routing.
* Added Gaussian, Poisson, quasi-Poisson, binomial, quasi-binomial, Gamma, inverse-Gaussian and optional negative-binomial GLM support.
* Added GLM dispersion, diagnostics, replicated-cell lack-of-fit assessment, response-scale canonical classification and response/link-scale plotting.
* Added two-factor nonlinear response surfaces with Mitscherlich, Gompertz, Michaelis-Menten, asymptotic, Hoerl, linear plateau, quadratic plateau and custom formulas.
* Added `rsm_nonlinear_start_ga()` and bounded random multistart parameter initialization. GA is used to obtain starting values, while final estimation remains `nlsLM`, `nls`, or `gnls`.
* Added optional `minpack.lm::nlsLM` and Tier-3 `nlme::gnls` backends, including power/exponential variance structures and user-supplied correlation structures.
* Generalized bounded/GA/hybrid optimization, optimum bootstrap, near-optimal regions, economic optimum, profiles and perturbation plots to the new model classes.
* Added cross-engine and optimum comparison helpers.
* Retained and documented Tier-3 GP, GAM/TPS, random forest, neural network and expected-improvement Bayesian optimization.
* Added five new vignettes and expanded manuals with at least three worked examples per new major module.
* Added GLM, nonlinear, GA-start, `gnls`, cross-engine and Tier-3 test/simulation scenarios.

# rsmFlow 0.1.0

* Extracted the scientific core from the supplied modular Shiny application.
* Generalized core fitting and optimization from two factors to two or more quantitative factors.
* Added design-aware diagnostics for non-orthogonal and imperfect RSM designs.
* Added prediction-variance/FDS summaries, approximate rotatability, and design augmentation.
* Added generalized canonical analysis, bounded/global optimization, optimum bootstrap inference, near-optimal regions, robust confidence-bound optimization, desirability/Pareto workflows, and economic optimum analysis.
* Mixture designs explicitly excluded from scope.
