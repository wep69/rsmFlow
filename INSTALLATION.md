# rsmFlow 0.2.0 development installation and validation

## Runtime

- R >= 4.2.0.
- Core imports: `stats`, `graphics`, `grDevices`, `utils`.
- GLM families in base R require no extra package; negative-binomial GLM requires `MASS`.
- GA starting-value search and global optimization require `GA`.
- `nlsLM` requires `minpack.lm`; if absent, the nonlinear helper can fall back to base `nls` where documented.
- `gnls` requires `nlme`.
- Tier-3 surrogates use `DiceKriging`, `mgcv`, `ranger`, and `nnet` as selected.

## Install the development source snapshot

From R:

```r
install.packages("rsmFlow_0.2.0-development.tar.gz", repos = NULL, type = "source")
library(rsmFlow)
```

The supplied tar.gz is a development source snapshot assembled outside R because R/Rscript is unavailable in the build environment. It is not the canonical `R CMD build` tarball.

## Minimum examples after installation

```r
# Classical
fit <- rsm_fit(dat,"Yield",c("N","K"),order=2)

# GLM-RSM
fit_g <- rsm_glm_fit(dat_count,"Insects",c("Dose","Days"),family=poisson())

# Nonlinear with GA starting values
fit_n <- rsm_nonlinear_fit(dat_nutrient,"Yield",c("N","P"),
                           model="mitscherlich2_product",start="ga",engine="nlsLM")
```

## Full Windows release gate

1. Install R and make `Rscript.exe` visible on `PATH`.
2. Install the packages listed in `Suggests` in `DESCRIPTION` for the strict full-backend check.
3. Extract the source ZIP.
4. Open PowerShell in the package root and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\VALIDATE_AND_BUILD_WINDOWS.ps1
```

The wrapper invokes `scripts/VALIDATE_AND_BUILD.R`, which:

- verifies that the declared Suggested packages needed by the strict gate are installed;
- runs `R CMD build`;
- runs `R CMD check --as-cran`;
- installs the resulting package into a clean temporary library;
- runs the extended smoke test covering classical RSM, GLM-RSM, nonlinear fitting and conditional GA/Tier-3 paths.

Review `validation/00check.log` and the console logs before release.

## Direct R validation

```r
source("scripts/VALIDATE_AND_BUILD.R")
```

## Frozen scientific simulation battery

Only after the runtime package gate passes:

```r
source("scripts/SIMULATION_BATTERY.R")
```

The extended battery includes GLM family behavior, nonlinear parameter recovery, GA-versus-multistart starting-value searches, GAM/TPS/GP/random-forest/neural-network surrogate scenarios, and a conditional `gnls` heteroscedasticity scenario in addition to the original design/optimization/economic simulations.

Do not alter frozen seeds or scenarios for publication use without documenting the change.

## CRAN metadata still requiring human input

Replace `REPLACE-BEFORE-CRAN@example.org` in `DESCRIPTION` with the real maintainer email before CRAN submission.
