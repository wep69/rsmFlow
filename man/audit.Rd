\name{rsm_design_audit}
\alias{rsm_design_audit}
\alias{rsm_diagnostics}
\alias{rsm_lack_of_fit}
\alias{print.rsmFlow_design_audit}
\title{Audit response-surface design and model adequacy}
\usage{
rsm_design_audit(object, grid_n = 15, rotatability = TRUE)
rsm_diagnostics(object)
rsm_lack_of_fit(object)
}
\arguments{
\item{object}{An \code{rsmFlow_fit} object.}
\item{grid_n}{Resolution used to summarize prediction variance over the declared region.}
\item{rotatability}{Whether to compute the approximate rotatability diagnostic when the model is estimable.}
}
\description{Reports rank, condition number, VIF, term correlations, prediction-variance/FDS summaries and related diagnostics. Lack of fit is decomposed only when replication permits pure-error estimation.}
