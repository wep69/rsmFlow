# Metadata verification status

Snapshot date: 2026-08-13.

Six core references used in the initial package justification and methodological documentation are recorded in `inst/metadata/reference_verification.csv` and `inst/metadata/references.ris`.

- `Lenth2009`, `BoxDraper1959`, `Wan2016`, `DerringerSuich1980`, and `JonesSchonlauWelch1998` were checked against two bibliographic/publisher/institutional records as recorded in the CSV.
- `ODriscoll2015` currently has two publisher-side metadata records rather than two independent providers and is therefore flagged `verified-publisher-two-records`; an independent Crossref/OpenAlex or equivalent check should be added before journal submission.

Reference verification is metadata verification, not replication of the scientific claims of each paper. Package-version statements are time-dependent and must be refreshed before CRAN release or manuscript submission.
