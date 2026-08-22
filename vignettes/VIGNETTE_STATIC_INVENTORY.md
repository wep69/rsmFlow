# rsmFlow vignette static inventory

**Audit date:** 2026-08-20  
**Package snapshot:** `rsmFlow 0.2.0-development`  
**Scope:** static documentation/source consistency only. No R runtime or vignette rendering is claimed by this audit.

## 1. Final active vignette inventory

| File | Lines | Words | Public functions referenced | Code-fence markers | SHA-256 |
|---|---:|---:|---:|---:|---|
| `00-foundations-to-advanced.Rmd` | 1,473 | 4,718 | 51 | 164 | `d58bc4ae2266816eed1258c43b21ee9634ff7b7763dd574088d18ff963f7873d` |
| `01-design-audit-and-augmentation.Rmd` | 469 | 1,801 | 13 | 56 | `ccba86e4bc924b662ef67ce1a2f3c131342517aa7c2b5700d87c6e2a760d140b` |
| `02-classical-rsm-geometry-diagnostics.Rmd` | 452 | 1,649 | 10 | 54 | `678243f6b4823f875c84e6bf284fb15cd8b3145abbe1d9aace68a8a7a39231f8` |
| `03-glm-and-nonlinear-surfaces.Rmd` | 578 | 1,758 | 15 | 68 | `42e8996fa68d637830bf2cdf6b6a75c20b0a7cf1d6717e9aa39cd23cbc4daa2f` |
| `04-optimization-uncertainty-economics.Rmd` | 493 | 1,531 | 14 | 50 | `a9f4787b70abd00eed3df7be86b9c4be1f8c5a1dab8f55718386953c22ce05e4` |
| `05-multiresponse-and-tier3.Rmd` | 549 | 1,641 | 15 | 60 | `61fd72ea9b75ce54cf4a6a58eb39aabdb651b664eb075123fd2771d71095e1a9` |
| `06-visualization-shiny-and-teaching.Rmd` | 444 | 1,359 | 21 | 56 | `6d31635f05035cd4c1e0e79fb55f14e248b68f4aa80a100ca45d19311b36db7d` |
| `07-validation-reproducibility-and-method-selection.Rmd` | 514 | 2,129 | 6 | 32 | `b8814f1e15cada6602d80a715a3dd3169d535edcec2a534ba39d2878fd167422` |

**Total R Markdown vignettes:** 8  
**Total lines:** 4,972  
**Total words:** 16,586

## 2. Public-API coverage

- `NAMESPACE` exports: **53**
- Distinct exported functions referenced by active vignettes: **53**
- Referenced public symbols absent from `NAMESPACE`: **0**
- Exported functions not referenced by any active vignette: **0**

**Result:** all 53 current exported functions are referenced by the reorganized vignette set, and no vignette calls an unexported `rsm_*`/`run_rsm_app` symbol.

## 3. Bibliography consistency

- Keys in `references.bib`: **8**
- Distinct citation keys used by the vignettes: **8**
- Citation keys missing from `references.bib`: **0**

Shared verified keys currently used:

- `BoxDraper1959`
- `DerringerSuich1980`
- `Frenzel2010`
- `JonesSchonlauWelch1998`
- `Landes1999`
- `Lenth2009`
- `ODriscoll2015`
- `Wan2016`

## 4. Structural checks

- PASS: All eight Rmd files start with YAML front matter.
- PASS: All Rmd code-fence marker counts are even.
- PASS: No former short Rmd filename remains active.
- PASS: Shared bibliography exists.
- PASS: Vignette organization document exists.

## 5. Former short-vignette replacement

The eleven former short Rmd files were removed from the active `vignettes/` directory after their content was consolidated into the eight long-form vignettes. A backup was retained outside the package source tree during this documentation task only; it is not part of the updated package archive.

## 6. Static corrections made during audit

The reorganization included source-level reconciliation against the current R implementation. Examples were corrected to use the current object fields and argument structures, including:

- coding metadata from `attr(coded, "rsmFlow_coding")` rather than obsolete list fields;
- `rsmFlow_design_audit` fields such as `estimable`, `exact_alias`, and `condition_number_scaled`;
- canonical output fields `stationary_point` and `nature`;
- nonlinear diagnostic fields `parameter_correlation` and `converged`;
- economic optimum fields `solution`, `profit`, and `biological_optimum`;
- current epsilon-constraint structure for `rsm_multiopt()`;
- current per-response `goal`/`low`/`high` constraint structure for `rsm_overlaid_contour()`;
- named `response1`/`response2` columns for `rsm_plot_pareto()`.

## 7. What this audit does not establish

- R parser success for every code chunk;
- package loadability;
- numerical equivalence to trusted methods;
- optional-backend compatibility;
- execution success of vignette examples;
- vignette rendering success;
- simulation coverage or optimizer convergence claims;
- `R CMD check --as-cran` success.

Those remain runtime gates and must be executed in a complete local R environment before release.
