# Static validation record

**Date:** 2026-08-13  
**Package:** rsmFlow 0.2.0 development snapshot

The build environment does not contain `R` or `Rscript`. This record is therefore deliberately restricted to source-level validation.

## Completed checks

- 18 package R files scanned for balanced parentheses/brackets/braces while respecting strings/comments/backtick identifiers;
- validation scripts and all 9 testthat files structurally scanned;
- all 53 `NAMESPACE` exports mapped to a single top-level implementation;
- no duplicate top-level function definitions remain;
- all 23 registered S3 methods mapped to an implementation;
- every exported public function mapped to at least one Rd alias;
- new GLM/nonlinear/Tier-3 manuals contain three worked workflows for each major module page;
- 11 vignettes are present, including dedicated GLM, nonlinear, Tier-3, engine-comparison and state-of-the-art tutorials;
- GLM prior/trial weights are preserved in refittable objects;
- the frozen simulation battery uses only exported package functions;
- runtime package source contains no automatic dependency installation;
- original 0.1.0 snapshot retained before modification;
- mixture experiments remain explicitly outside package scope.

## Not established by static validation

Static validation does not establish:

- R-parser success;
- package loadability;
- numerical correctness/tolerances;
- model recovery or coverage;
- optimizer convergence rates;
- optional-backend compatibility;
- example/test/vignette execution success;
- CRAN compliance.

Those are runtime gates delegated to `scripts/VALIDATE_AND_BUILD.R`, followed by the frozen `scripts/SIMULATION_BATTERY.R` for scientific validation.
