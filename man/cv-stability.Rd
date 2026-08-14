\name{rsm_cv}
\alias{rsm_cv}
\alias{rsm_optimum_stability}
\title{Structured cross-validation and optimum stability}
\usage{
rsm_cv(object, folds = 5, repeats = 1, group = NULL, seed = 123)
rsm_optimum_stability(uncertainty, fit, tolerance = 0.10)
}
\arguments{
\item{object}{An \code{rsmFlow_fit} object.}
\item{folds}{Number of cross-validation folds.}
\item{repeats}{Number of repeated fold assignments.}
\item{group}{Optional grouping column/vector kept intact across folds.}
\item{seed}{Random-number seed.}
\item{uncertainty}{Object returned by \code{rsm_optimum_ci()}.}
\item{fit}{The fitted response-surface object used to standardize optimum coordinates.}
\item{tolerance}{Standardized-radius threshold used in the stability summary.}
}
\description{Cross-validation can keep blocks or experimental units together through group=. Optimum stability summarizes the bootstrap distribution in factor-range standardized coordinates and quantifies fitted-response loss near the estimated optimum.}
