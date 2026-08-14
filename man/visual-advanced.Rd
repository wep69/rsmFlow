\name{rsm_profile}
\alias{rsm_profile}
\alias{rsm_perturbation}
\alias{rsm_overlaid_contour}
\alias{rsm_desirability_surface}
\alias{rsm_plot_pareto}
\alias{plot.rsmFlow_profile}
\alias{plot.rsmFlow_perturbation}
\alias{plot.rsmFlow_fds}
\alias{plot.rsmFlow_vdg}
\alias{plot.rsmFlow_overlaid}
\alias{plot.rsmFlow_desirability_surface}
\alias{plot.rsmFlow_slices}
\title{Advanced response-surface visualization helpers}
\usage{
rsm_profile(object, factor, at = NULL, n = 100,
  interval = c("confidence", "none"), level = 0.95)
rsm_perturbation(object, reference = NULL, n = 100, standardized = TRUE)
rsm_overlaid_contour(fits, constraints, x = NULL, y = NULL, at = NULL, n = 100)
rsm_desirability_surface(fits, goals, limits, importance = NULL,
  x = NULL, y = NULL, at = NULL, n = 100)
rsm_plot_pareto(pareto, response_x = NULL, response_y = NULL)
}
\arguments{
\item{object}{An \code{rsmFlow_fit} object.}
\item{factor}{Factor varied in a one-dimensional profile.}
\item{at}{Named fixed values for factors not displayed.}
\item{n}{Grid/profile resolution.}
\item{interval}{Whether to add model-based confidence intervals when supported.}
\item{level}{Confidence level.}
\item{reference}{Reference factor combination for perturbation profiles.}
\item{standardized}{Express perturbation displacement in factor half-range units.}
\item{fits}{List of fitted response-surface models using the same quantitative factors.}
\item{constraints}{Per-response feasibility rules for overlaid contours.}
\item{x,y}{Factors displayed on a two-dimensional surface.}
\item{goals}{Per-response desirability goals.}
\item{limits}{Per-response desirability limits.}
\item{importance}{Optional response importance weights.}
\item{pareto}{Data frame returned by \code{rsm_pareto()}.}
\item{response_x,response_y}{Response columns shown in a Pareto plot.}
}
\description{Creates conditional response profiles, perturbation plots, overlaid feasibility regions, multiresponse desirability surfaces and Pareto plots. S3 plot methods also render FDS, VDG and sliced-surface objects.}
