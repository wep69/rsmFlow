# rsmFlow vignette organization

**Package:** `rsmFlow`  
**Target development snapshot:** `0.2.0-development`  
**Purpose:** explain the pedagogical architecture, content ownership, reading order, and replacement of the former short-vignette set.

## 1. Why the vignette collection was reorganized

The previous vignette directory contained eleven short tutorials. They were useful as feature demonstrations, but several subjects were repeated across multiple files. In particular, advanced surrogates, Tier-3 integration, engine comparison, optimization, graphics, and state-of-the-art positioning were distributed across separate short documents with overlapping explanations.

The reorganized collection follows a different principle:

> **One integrated starting tutorial plus a small number of deep dives, each with explicit ownership of a scientific block.**

The objective is not to maximize the number of vignette files. The objective is to make the learning path coherent for beginners while preserving sufficient methodological depth for advanced users.

The main tutorial introduces the entire evidence chain:

**Design -> Audit -> Fit -> Diagnose -> Geometry -> Optimize -> Quantify uncertainty -> Compare alternatives -> Decide.**

The seven deep dives then develop one part of that chain without reproducing full chapters owned by another vignette.

## 2. Final vignette set

| Order | File | Primary role | Main audience |
|---:|---|---|---|
| 0 | `00-foundations-to-advanced.Rmd` | Integrated starting point from design through Tier 3 and Shiny | All users |
| 1 | `01-design-audit-and-augmentation.Rmd` | Experimental design, coding, non-orthogonality, precision, FDS/VDG, augmentation | Beginner -> advanced |
| 2 | `02-classical-rsm-geometry-diagnostics.Rmd` | FO/SO models, hierarchy, residual diagnostics, lack of fit, canonical analysis, steepest/ridge paths | Beginner -> intermediate |
| 3 | `03-glm-and-nonlinear-surfaces.Rmd` | Non-Gaussian GLM-RSM and biologically interpretable nonlinear surfaces | Intermediate -> advanced |
| 4 | `04-optimization-uncertainty-economics.Rmd` | Bounded/global/target optimization, optimum uncertainty, near-optimal regions, economic optimum | Intermediate -> advanced |
| 5 | `05-multiresponse-and-tier3.Rmd` | Desirability, Pareto/NSGA-II, constraints, GP/GAM/TPS/RF/NN, Bayesian optimization | Advanced |
| 6 | `06-visualization-shiny-and-teaching.Rmd` | Static/interactive visualization, high-dimensional views, Shiny-to-code bridge, teaching | All users/instructors |
| 7 | `07-validation-reproducibility-and-method-selection.Rmd` | Simulation validation, model comparison, reproducibility, state-of-the-art positioning, release gates | Advanced/developers |

Shared bibliography:

- `references.bib`

Organization documents:

- `VIGNETTE_ORGANIZATION.md` — this file;
- `VIGNETTE_STATIC_INVENTORY.md` — static inventory and consistency audit of the reorganized set.

## 3. Content ownership rules

The collection deliberately separates **introduction** from **ownership**.

The integrated tutorial may introduce a function so that a new user sees the complete workflow. Detailed explanation belongs to one deep dive only.

### Block A: design and information geometry

Primary owner:

`01-design-audit-and-augmentation.Rmd`

Functions:

```text
rsm_design()
rsm_code()
rsm_decode()
rsm_design_audit()
rsm_orthogonality()
rsm_rotatability()
rsm_prediction_variance()
rsm_compare_designs()
rsm_augment()
rsm_fds()
rsm_vdg()
```

This vignette explains design generation, custom/imperfect designs, full rank versus orthogonality, numerical conditioning, prediction variance, FDS, VDG, rotatability, and augmentation. Later files should reference these ideas rather than repeat the full design theory.

### Block B: classical polynomial RSM and geometry

Primary owner:

`02-classical-rsm-geometry-diagnostics.Rmd`

Functions:

```text
rsm_fit()
rsm_lack_of_fit()
rsm_diagnostics()
rsm_canonical()
rsm_steepest()
rsm_ridge()
```

This vignette owns polynomial hierarchy, estimator choices, residual/influence diagnostics, pure-error lack of fit, canonical eigenstructure, stationary-point classification, steepest ascent/descent, and ridge exploration.

### Block C: GLM and nonlinear response surfaces

Primary owner:

`03-glm-and-nonlinear-surfaces.Rmd`

Functions:

```text
rsm_glm_fit()
rsm_glm_dispersion()
rsm_glm_diagnostics()
rsm_glm_lack_of_fit()
rsm_glm_canonical()
rsm_nonlinear_models()
rsm_nonlinear_start_ga()
rsm_nonlinear_start_multistart()
rsm_nonlinear_fit()
rsm_nonlinear_diagnostics()
```

The file distinguishes response-family selection from nonlinear biological parameterization. GA is explained here only as a search for nonlinear starting values. Surface optimization by GA belongs to the optimization vignette.

### Block D: single-response decision and uncertainty

Primary owner:

`04-optimization-uncertainty-economics.Rmd`

Functions:

```text
rsm_optimize()
rsm_optimum_ci()
rsm_optimum_region()
rsm_near_optimal()
rsm_robust_optimize()
rsm_economic_optimum()
rsm_optimum_stability()
rsm_plot_optimum_uncertainty()
```

This file distinguishes unconstrained geometry from bounded operational decisions, explains optimizer comparison, propagates model uncertainty into the optimum, and develops biological-versus-economic decisions.

### Block E: multiple responses and Tier 3

Primary owner:

`05-multiresponse-and-tier3.Rmd`

Functions:

```text
rsm_desirability()
rsm_multiopt()
rsm_pareto()
rsm_overlaid_contour()
rsm_desirability_surface()
rsm_plot_pareto()
rsm_surrogate()
rsm_surrogate_optimize()
rsm_bayes_opt()
rsm_cv()
rsm_compare_engines()
rsm_compare_optima()
```

This vignette owns the distinction between soft preferences, hard constraints, and Pareto trade-offs. It also owns escalation to flexible surrogate models and the one-step Bayesian-optimization workflow.

### Block F: visualization and interactive teaching

Primary owner:

`06-visualization-shiny-and-teaching.Rmd`

Functions:

```text
rsm_plot()
rsm_slices()
rsm_profile()
rsm_perturbation()
rsm_explain()
run_rsm_app()
```

The file teaches which visualization answers which scientific question and uses Shiny as an interface to the same public R API rather than as a separate statistical engine.

### Block G: validation and release-quality comparison

Primary owner:

`07-validation-reproducibility-and-method-selection.Rmd`

This block uses functions from all earlier modules but owns the **validation protocol**, not the methods themselves. It covers frozen simulation scenarios, numerical truth tests, backend verification, model/optimum comparison, state-of-the-art positioning, reproducibility records, Shiny parity, and `R CMD check` release gates.

## 4. Recommended reading routes

### Route 1: first response-surface analysis

```text
00 Foundations to Advanced
        ↓
01 Design Audit and Augmentation
        ↓
02 Classical RSM, Geometry, and Diagnostics
        ↓
04 Optimization, Uncertainty, and Economics
        ↓
06 Visualization, Shiny, and Teaching
```

This route is appropriate for students and researchers working with continuous approximately Gaussian responses.

### Route 2: counts, proportions, or positive skewed responses

```text
00 Foundations to Advanced
        ↓
01 Design Audit
        ↓
03 GLM and Nonlinear Surfaces
        ↓
04 Optimization and Uncertainty
        ↓
06 Visualization
```

### Route 3: biological saturation or plateau

```text
00 Foundations to Advanced
        ↓
03 GLM and Nonlinear Surfaces
        ↓
04 Optimization and Uncertainty
        ↓
07 Validation and Method Selection
```

### Route 4: multiresponse decision

```text
00 Foundations to Advanced
        ↓
02 or 03: fit each response appropriately
        ↓
04: understand single-response optima
        ↓
05 Multiresponse and Tier 3
        ↓
06 Visualization
```

### Route 5: advanced surrogate / sequential experimentation

```text
00 Foundations to Advanced
        ↓
01 Design Audit
        ↓
02/03 simpler benchmark model
        ↓
05 Multiresponse and Tier 3
        ↓
07 Validation and Method Selection
```

Tier-3 methods should be compared against simpler models rather than used as a default starting point.

### Route 6: package validation or methods development

```text
00 Foundations to Advanced
        ↓
all relevant owner vignettes
        ↓
07 Validation, Reproducibility, and Method Selection
        ↓
LOCAL VALIDATION GUIDE
```

## 5. Former short vignettes and their new destination

| Former file | Disposition | New owner |
|---|---|---|
| `00-getting-started.Rmd` | replaced and greatly expanded | `00-foundations-to-advanced.Rmd` |
| `01-nonorthogonal-designs.Rmd` | absorbed | `01-design-audit-and-augmentation.Rmd` |
| `02-optimization-uncertainty.Rmd` | absorbed and expanded | `04-optimization-uncertainty-economics.Rmd` |
| `03-multiresponse-economics.Rmd` | split by scientific responsibility | economics -> `04`; multiresponse -> `05` |
| `04-graphics-teaching.Rmd` | absorbed and expanded | `06-visualization-shiny-and-teaching.Rmd` |
| `05-advanced-surrogates.Rmd` | absorbed | `05-multiresponse-and-tier3.Rmd` |
| `06-glm-response-surfaces.Rmd` | absorbed | `03-glm-and-nonlinear-surfaces.Rmd` |
| `07-nonlinear-response-surfaces.Rmd` | absorbed | `03-glm-and-nonlinear-surfaces.Rmd` |
| `08-tier3-integrated.Rmd` | merged with advanced-surrogate content | `05-multiresponse-and-tier3.Rmd` |
| `09-engine-comparison.Rmd` | comparison logic moved to validation | `05` for practical comparison; `07` for validation principles |
| `10-state-of-the-art.Rmd` | integrated into methodological validation/positioning | `07-validation-reproducibility-and-method-selection.Rmd` |

The former files should **not** remain in the package's active `vignettes/` directory because that would recreate the duplication this reorganization is intended to remove.

## 6. How overlap is controlled

### Rule 1. One detailed owner per concept

For example, non-orthogonality is introduced in the main tutorial but its detailed explanation belongs to vignette 01.

### Rule 2. Functions can reappear in integrated workflows

`rsm_optimize()` can appear in the GLM or nonlinear vignette to complete an example, but optimizer theory and uncertainty are owned by vignette 04.

### Rule 3. Repetition is allowed only when pedagogically necessary

A short reminder is acceptable. Repeating full derivations, tables of methods, or identical code workflows is not.

### Rule 4. Validation uses methods without reteaching them

Vignette 07 can call `rsm_glm_fit()` in a simulation, but it should discuss parameter recovery and coverage rather than repeat the GLM-family tutorial.

### Rule 5. Visualization is centralized

Method-specific vignettes can show one or two essential plots, while visualization choices, conditional slices, interactivity, and GUI pedagogy belong to vignette 06.

## 7. Pedagogical template used throughout

The long vignettes follow a recurring pattern:

```text
Scientific problem
    ↓
Concept and assumptions
    ↓
R code
    ↓
Table or figure
    ↓
Basic interpretation
    ↓
Advanced interpretation / caveat
    ↓
Common mistakes
    ↓
Reporting checklist
```

This pattern is intentionally similar across files so a learner knows what to expect without duplicating scientific content.

## 8. Examples and execution policy

The current development snapshot uses:

```r
knitr::opts_chunk$set(eval = FALSE)
```

in the reorganized long vignettes.

Reasons:

1. the documentation reorganization was performed without a complete certified R runtime in the generation environment;
2. several advanced modules depend on optional backends;
3. GA, bootstrap, simulation, GP, RF, NN, and Bayesian-optimization examples can be computationally expensive;
4. release-quality claims must distinguish static documentation audit from executed runtime validation.

Before release, the local validation workflow should execute representative examples, render all vignettes, run tests, run the simulation battery, and finish with `R CMD check --as-cran`.

## 9. Example-data policy

Three types of examples are used:

1. **Bundled package example:** `inst/extdata/agronomy_rsm_nonorthogonal.csv` for realistic design/audit workflows.
2. **Frozen synthetic teaching examples:** generated with explicit `set.seed()` for known maxima, saddles, GLM responses, and nonlinear parameter recovery.
3. **Schematic commented examples:** used only when a specialist backend or data structure would otherwise distract from the conceptual point.

Synthetic examples are teaching instruments, not field evidence.

## 10. Function coverage policy

The reorganized vignette set is designed so that every exported public function in the current `NAMESPACE` is referenced by at least one vignette.

The static inventory records:

- exported function count;
- vignette-referenced export count;
- referenced-but-unexported symbols;
- missing bibliography keys;
- code-fence consistency;
- file line/word counts.

Function appearance alone does not establish runtime validity; that remains part of the local release gates.

## 11. Bibliography policy

All vignettes use the shared `references.bib` rather than maintaining separate repeated bibliographies.

The bibliography currently supports the central methodological references for:

- classical RSM;
- response-surface design;
- non-orthogonality/design selection;
- optimum confidence sets;
- desirability;
- efficient global/Bayesian optimization;
- nonlinear multifactor agronomic response.

New references should be added only after their metadata are verified.

## 12. Mixture-experiment boundary

Mixture experiments remain outside the scope of `rsmFlow` and should not be introduced in these vignettes as though the package supports them.

The package focuses on quantitative-factor response-surface experiments and the documented extensions around that framework.

## 13. Maintenance rule for future functions

When a new exported function is added:

1. assign it to one primary vignette owner;
2. add a realistic example to that vignette;
3. update the integrated tutorial only if the function changes the overall workflow;
4. update `VIGNETTE_STATIC_INVENTORY.md`;
5. run static symbol/citation checks;
6. run runtime examples and tests locally;
7. render vignettes and run `R CMD check --as-cran` before release.

Do not create a new short vignette solely because a new function exists.

## 14. Final learning principle

The eight active vignettes are intended to form one curriculum rather than eight unrelated manuals.

For beginners, the curriculum answers:

> What should I do next, and why?

For advanced users, it answers:

> Which assumptions, diagnostics, uncertainty sources, and decision consequences change when I choose a more advanced method?

That is the organizing principle for the entire `rsmFlow` vignette ecosystem.
