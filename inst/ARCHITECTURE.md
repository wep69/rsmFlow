# rsmFlow 0.2.0 architecture

```text
Design / imported quantitative-factor experiment
        |
        +---------------- Classical polynomial RSM (2+ factors)
        |                    |
        |                    +--> design audit / augmentation / FDS / VDG
        |                    +--> canonical / steepest / ridge
        |
        +---------------- Two-factor GLM-RSM
        |                    |
        |                    +--> family/link diagnostics
        |                    +--> response-scale canonical geometry
        |
        +---------------- Two-factor nonlinear RSM
        |                    |
        |                    +--> parameter bounds
        |                    +--> GA or random multistart initialization
        |                    +--> nlsLM / nls / gnls final fit
        |                    +--> identifiability diagnostics
        |
        +---------------- Tier 3 explicit surrogates
                             |
                             +--> GP / GAM-TPS / RF / NN
                             +--> one-step expected improvement

All compatible fitted models
        |
        +--> common response prediction
        +--> bounded / GA / hybrid optimization
        +--> bootstrap optimum uncertainty where refitting is defined
        +--> near-optimal / stability / economic decision layers
        +--> multiresponse prediction and compromise optimization
        +--> contour / heatmap / 3D / profile / perturbation graphics
```

## Classes

- `rsmFlow_fit`: design-aware Gaussian polynomial RSM.
- `rsmFlow_glm`: two-factor generalized polynomial RSM.
- `rsmFlow_nonlinear`: two-factor mechanistic/semi-empirical nonlinear surface.
- `rsmFlow_surrogate`: Tier-3 predictive surrogate.

The common helpers retain response name, quantitative factor names, declared factor bounds and original data. Model-specific quantities remain model-specific: for example, FDS/VDG derive from a polynomial design matrix and are not fabricated for arbitrary nonlinear or machine-learning surfaces.
