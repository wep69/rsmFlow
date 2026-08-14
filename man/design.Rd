\name{rsm_design}
\alias{rsm_design}
\alias{rsm_code}
\alias{rsm_decode}
\alias{rsm_orthogonality}
\alias{rsm_rotatability}
\alias{rsm_prediction_variance}
\alias{rsm_compare_designs}
\alias{rsm_augment}
\alias{rsm_fds}
\alias{rsm_vdg}
\title{Response-surface design generation and design-aware diagnostics}
\arguments{
\item{factors}{Names of two or more quantitative factors.}
\item{type}{Design type; mixture designs are deliberately excluded.}
\item{levels}{Candidate levels used when an optimal-design candidate set is generated automatically.}
\item{n0}{Number of centre points for CCD/BBD generation.}
\item{alpha}{CCD axial-distance option passed to the optional \pkg{rsm} backend.}
\item{runs}{Requested number of runs for optimal-design selection.}
\item{candidates}{Optional candidate-set data frame.}
\item{data}{Data frame for custom designs or factor coding.}
\item{randomize}{Whether generated classical designs should be randomized.}
\item{seed}{Random-number seed.}
\item{center,scale}{Named coding centre and half-range vectors.}
\item{coding}{Coding metadata returned by \code{rsm_code()}.}
\item{x}{A fit or design object, depending on the function.}
\item{order}{Polynomial order used to form the model matrix.}
\item{radii}{Coded radii used in the rotatability diagnostic.}
\item{points}{Number of random directions per radius.}
\item{object}{An \code{rsmFlow_fit} object.}
\item{newdata}{Optional factor combinations at which prediction variance is evaluated.}
\item{n}{Grid resolution.}
\item{scaled}{Return variance divided by the residual variance when \code{TRUE}.}
\item{...}{Named designs supplied to \code{rsm_compare_designs()}.}
\item{n_add}{Number of augmentation runs to propose.}
\item{objective}{D-, A-, I-, G-, or conditioning-oriented greedy augmentation criterion.}
\item{grid_n}{Candidate-grid resolution for augmentation.}
\item{radii}{Standardized radii for rotatability or variance-dispersion summaries.}
\item{points}{Number of random sphere directions at each radius.}
}
\description{Generate or wrap response-surface designs, code/decode factors, quantify orthogonality and prediction variance, generate FDS/VDG diagnostics, compare designs, and suggest augmentation points.}
\usage{
rsm_design(factors, type = c("ccd", "ccd_circumscribed", "ccd_face", "ccd_inscribed", "bbd", "d_optimal", "i_optimal", "custom"),
  levels = NULL, n0 = 4, alpha = "rotatable", runs = NULL,
  candidates = NULL, data = NULL, randomize = TRUE, seed = NULL)
rsm_code(data, factors, center = NULL, scale = NULL)
rsm_decode(data, coding)
rsm_orthogonality(x, factors = NULL, order = 2)
rsm_rotatability(x, radii = c(0.5, 1), points = 500, seed = 123)
rsm_prediction_variance(object, newdata = NULL, n = 25, scaled = TRUE)
rsm_compare_designs(..., factors = NULL, order = 2)
rsm_augment(object, n_add = 4, candidates = NULL, objective = c("D", "A", "I", "G", "condition"), grid_n = 9, seed = 123)
rsm_fds(object, n = 20000, seed = 123)
rsm_vdg(object, radii = seq(0, 1, length.out = 21), points = 1000, seed = 123)
}
\details{Mixture designs are deliberately not supported. Non-orthogonality is assessed through its effects on estimability, conditioning and prediction precision.}
