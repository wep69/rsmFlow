# Migration from the supplied modular Shiny application

## Source assets reviewed

The supplied application already contained useful modules for design generation, desirability, lack of fit, diagnostics, model comparison, cross-validation, confidence regions, robustness, Box-Cox transformation, ridge analysis, steepest ascent, advanced plots, batch analysis, reports and session/history support.

## Architectural changes

The package does not source Shiny modules from the scientific core. Statistical methods are exposed first as ordinary R functions, then reused by the optional Shiny app.

## Major scientific/software changes from the supplied app

1. The supplied optimization helpers and several visualization/canonical routines were explicitly written for two factors. `rsmFlow` generalizes the core fit, canonical analysis, optimization and inference to two or more quantitative factors.
2. Startup-time package installation in the supplied app is not used by the package. Dependencies are declared in `DESCRIPTION` and optional capabilities fail with informative messages.
3. The supplied bootstrap included case resampling. `rsmFlow` defaults to residual or parametric bootstrap and labels case bootstrap as a method that can disrupt designed-experiment structure.
4. Stationary-point analysis is separated from bounded optimization, so saddle points and stationary points outside the experimental region are not labeled as optima.
5. Design quality is expanded beyond basic VIF to rank, raw/scaled conditioning, term correlation, information eigenvalues, prediction variance, FDS summaries, approximate rotatability, and augmentation suggestions.
6. Economic optimum, near-optimal regions, confidence-bound optimization, high-dimensional slices, and explicit biological-versus-economic comparison are new core capabilities.
7. Remote fonts/icons and other web assets in the original UI are not required by the new package interface.
8. The optional app in `inst/shiny/app.R` is intentionally thin and calls the package API.

## Provenance

The original files remain the user's source material and are not duplicated in the distributable package snapshot. This document records the migration decisions without making the original Shiny code part of the installed scientific library.
