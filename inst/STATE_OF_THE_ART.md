# rsmFlow 0.2.0: state of the art, gap, and expanded scope

**Snapshot date:** 2026-08-13  
**Scope:** quantitative-factor response surfaces; mixture experiments are intentionally excluded.

## Classical response-surface layer

The established `rsm` ecosystem remains the reference for classical first- and second-order response-surface modelling, coding, canonical analysis, steepest ascent, ridge analysis, CCD and Box-Behnken designs. `rsmFlow` does not claim that R lacks classical RSM software. Its contribution is an integrated design-aware workflow covering imperfect/non-orthogonal designs, prediction-variance diagnostics, augmentation, bounded/global optimization, uncertainty of optimum coordinates, near-optimal decision regions, multiple responses, economics, and modern visualization.

## Why add GLM response surfaces?

A quadratic response surface can be embedded in a generalized linear model by specifying the second-order polynomial on the linear-predictor scale. This permits response supports and mean-variance relationships that are not naturally represented by homoscedastic Gaussian errors. `rsmFlow 0.2.0` therefore adds two-factor GLM-RSM with Gaussian, Poisson, quasi-Poisson, binomial, quasi-binomial, Gamma, inverse-Gaussian, and optional negative-binomial fitting.

The implementation follows the semantics of the official R `glm`/`family` interfaces. Response-scale prediction and optimization are the defaults. Quasi-likelihood fits are not ranked by ordinary likelihood AIC/BIC in cross-engine comparisons.

## Why add nonlinear two-factor surfaces?

The agricultural literature provides a direct justification. Landes, Stroup, Paparozzi and Conley (1999; DOI 10.4148/2475-7772.1263) reported plant-nutrition cases in which conventional second-order response surfaces had unacceptable lack of fit and developed multifactor Mitscherlich and Gompertz alternatives. Frenzel, Stroup and Paparozzi (2010; DOI 10.4148/2475-7772.1070) further examined nonlinear dose-response models and design strategies, emphasizing diminishing returns, convergence, and simulation-based evaluation.

`rsmFlow 0.2.0` implements two-factor built-in surfaces for:

- Mitscherlich product and offset variants;
- Gompertz product;
- Michaelis-Menten product;
- additive asymptotic response;
- Hoerl surface;
- increasing two-factor linear plateau;
- smooth increasing two-factor quadratic plateau;
- user-defined custom nonlinear formulas.

These forms are not declared universally superior. They represent candidate scientific hypotheses whose adequacy, identifiability, convergence, prediction, and optimum stability must be evaluated.

## Initial-value problem and GA

Nonlinear regression is sensitive to starting parameters. `rsmFlow` explicitly separates **parameter initialization** from **final estimation**. `rsm_nonlinear_start_ga()` minimizes residual sum of squares over named parameter bounds using the optional `GA` package. The resulting parameter vector becomes the start for `nlsLM`, `nls`, or `gnls`; GA is not presented as the inferential estimator. A bounded random-multistart alternative is available and is used transparently if GA is unavailable.

## Tier 3

Tier 3 remains expert-only and contains:

1. `nlme::gnls` for nonlinear mean functions with heterogeneous/correlated errors;
2. Gaussian-process surrogates (`DiceKriging`);
3. GAM surfaces with main smooths plus pairwise tensor interactions and joint multivariate thin-plate smooths (`mgcv`);
4. random-forest surrogates (`ranger`);
5. neural-network surrogates (`nnet`);
6. one-step expected-improvement Bayesian optimization.

The Bayesian-optimization workflow recommends the **next experimental point only**. It does not fabricate a future response or continue sequentially without a newly observed outcome.

## Unified model semantics

The public prediction/decision layer recognizes:

- `rsmFlow_fit`;
- `rsmFlow_glm`;
- `rsmFlow_nonlinear`;
- `rsmFlow_surrogate`.

Common operations include bounded/GA/hybrid optimization, profiles, perturbation plots, response surfaces, near-optimal regions, multiresponse prediction and economic optimization when mathematically meaningful. Classical design-variance/FDS/VDG diagnostics remain attached to the polynomial design-aware model because those quantities derive directly from the polynomial model matrix.

## Gap statement after expansion

Within the reviewed ecosystem, the defensible novelty is the integration of:

1. explicit diagnostics and repair suggestions for imperfect/non-orthogonal response-surface designs;
2. classical RSM and canonical/sequential geometry;
3. two-factor GLM response surfaces with response-scale optimization;
4. two-factor nonlinear agronomic surfaces;
5. GA or multistart nonlinear parameter initialization separated from final estimation;
6. optional `gnls` variance/correlation structures;
7. bounded/local/global optimization and optimum uncertainty;
8. near-optimal and economic decision regions;
9. multiple-response desirability/Pareto workflows;
10. explicit Tier-3 surrogate and Bayesian-optimization pathways;
11. one plotting/decision interface spanning several model classes;
12. a teaching-oriented documentation layer and reproducibility/validation battery.

## Limitations

- GLM-RSM and nonlinear built-ins are currently restricted to two quantitative factors; classical polynomial RSM supports two or more.
- Nonlinear formula choice remains scientifically model-dependent.
- Plateau parameterizations can create difficult/non-smooth optimization geometry.
- Classical canonical analysis is not claimed for arbitrary nonlinear surfaces.
- `gnls`, GA, GP, GAM/TPS, random forest, neural network, NSGA-II, and interactive graphics require optional packages.
- Runtime numerical certification and `R CMD check --as-cran` must be completed in an R environment before release claims.

## Core verified references

- Lenth RV. 2009. Response-Surface Methods in R, Using rsm. Journal of Statistical Software 32(7):1-17. DOI 10.18637/jss.v032.i07.
- Box GEP, Draper NR. 1959. A Basis for the Selection of a Response Surface Design. JASA 54(287):622-654. DOI 10.1080/01621459.1959.10501525.
- O'Driscoll D, Ramirez DE. 2015. Response surface designs using the generalized variance inflation factors. Cogent Mathematics 2:1053728. DOI 10.1080/23311835.2015.1053728.
- Wan F, Liu W, Bretz F, Han Y. 2016. Confidence sets for optimal factor levels of a response surface. Biometrics 72:1285-1293. DOI 10.1111/biom.12500.
- Derringer G, Suich R. 1980. Simultaneous Optimization of Several Response Variables. Journal of Quality Technology 12:214-219. DOI 10.1080/00224065.1980.11980968.
- Jones DR, Schonlau M, Welch WJ. 1998. Efficient Global Optimization of Expensive Black-Box Functions. Journal of Global Optimization 13:455-492. DOI 10.1023/A:1008306431147.
- Landes RD, Stroup WW, Paparozzi ET, Conley ME. 1999. NONLINEAR MODELS FOR MULTI-FACTOR PLANT NUTRITION EXPERIMENTS. DOI 10.4148/2475-7772.1263.
- Frenzel MJ, Stroup WW, Paparozzi ET. 2010. AFTER FURTHER REVIEW: AN UPDATE ON MODELING AND DESIGN STRATEGIES FOR AGRICULTURAL DOSE-RESPONSE EXPERIMENTS. DOI 10.4148/2475-7772.1070.

Reference-verification records are stored in `inst/metadata/reference_verification.csv` and RIS metadata in `inst/metadata/references.ris`.
