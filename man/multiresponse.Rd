\name{rsm_multiopt}
\alias{rsm_multiopt}
\alias{rsm_desirability}
\alias{rsm_pareto}
\title{Multiple-response optimization}
\usage{
rsm_desirability(y, goal = c("max", "min", "target", "interval"), low, high, target = NULL, weight = 1)
rsm_multiopt(fits, goals, limits, method = c("desirability", "pareto", "weighted", "distance", "epsilon"), importance = NULL, optimizer = c("GA", "L-BFGS-B"), seed = 123, sample_n = 5000, primary = 1, epsilon = NULL)
rsm_pareto(fits, goals, n = 5000, engine = c("sample", "NSGA2"), seed = 123)
}
\arguments{
\item{y}{Response values for an individual desirability transformation.}
\item{goal,goals}{Single or per-response goals: maximize, minimize, target, or interval as supported.}
\item{low,high,target,weight}{Individual desirability limits, target, and shape weight.}
\item{fits}{List of two or more \code{rsmFlow_fit} objects using the same factors.}
\item{limits}{Per-response lists defining low/high and optional target/shape values.}
\item{method}{Multiple-response decision rule.}
\item{importance}{Optional response importance weights.}
\item{optimizer}{GA or bounded local optimizer.}
\item{seed}{Random-number seed.}
\item{sample_n}{Approximate number of points for sampled Pareto search.}
\item{primary}{Index of the primary response in epsilon-constraint optimization.}
\item{epsilon}{Optional secondary-response thresholds.}
\item{n}{Requested sampling size for Pareto approximation.}
\item{engine}{Sampled Pareto search or optional NSGA-II backend.}
}
\description{Combines fitted responses using desirability, weighted compromise, distance-to-target, epsilon constraints, or Pareto analysis. Pareto search can use an approximate sampled front or optional NSGA-II via mco.}
