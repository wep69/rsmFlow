\name{rsm_canonical}
\alias{rsm_canonical}
\alias{rsm_steepest}
\alias{rsm_ridge}
\alias{print.rsmFlow_canonical}
\title{Canonical, steepest-direction and ridge analyses}
\usage{
rsm_canonical(object, tol = 1e-7)
rsm_steepest(object, direction = c("ascent", "descent"), step = 0.1,
  n_steps = 10, start = NULL, standardized = TRUE)
rsm_ridge(object, radii = seq(0.1, 1, by = 0.1), goal = c("max", "min"),
  center = NULL, n_starts = 20, seed = 123)
}
\arguments{
\item{object}{An \code{rsmFlow_fit} object.}
\item{tol}{Relative tolerance for identifying near-flat canonical curvatures.}
\item{direction}{Steepest ascent or descent.}
\item{step}{Step size in standardized factor-range units when \code{standardized=TRUE}.}
\item{n_steps}{Number of sequential steps.}
\item{start}{Optional starting point in natural factor units.}
\item{standardized}{Whether the steepest direction is scaled by factor half-ranges.}
\item{radii}{Ridge radii in standardized factor-space units.}
\item{goal}{Maximize or minimize the fitted response.}
\item{center}{Optional ridge centre in natural units.}
\item{n_starts}{Number of numerical starts per ridge radius.}
\item{seed}{Random-number seed.}
}
\description{Characterizes second-order surface geometry and supports sequential exploration when the stationary point is unsuitable or a ridge/flat direction exists.}
