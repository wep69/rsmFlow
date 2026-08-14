\name{rsm_plot}
\alias{rsm_plot}
\alias{rsm_slices}
\alias{rsm_plot_optimum_uncertainty}
\alias{rsm_explain}
\alias{run_rsm_app}
\title{Visualization and teaching tools across response-surface engines}
\usage{
rsm_plot(object, type = c("contour", "heatmap", "surface", "prediction_variance",
  "residuals", "qq", "leverage", "cooks", "term_correlation", "design", "fds",
  "vdg", "canonical", "profile", "perturbation"), x = NULL, y = NULL,
  at = NULL, n = 60, interactive = FALSE, show_points = TRUE,
  optimum = NULL, scale = c("response","link"))
rsm_plot_optimum_uncertainty(uncertainty, x = NULL, y = NULL, conf = NULL)
rsm_slices(object, x = NULL, y = NULL, slice_factor = NULL, values = NULL, n = 50)
rsm_explain(object)
run_rsm_app()
}
\arguments{
\item{object}{Supported rsmFlow model. Design-specific plot types require a polynomial \code{rsmFlow_fit}.}
\item{type}{Requested response or diagnostic plot.}
\item{x,y}{Displayed factors.}
\item{at}{Fixed values for undisplayed factors.}
\item{n}{Plot-grid resolution.}
\item{interactive}{Use Plotly when available.}
\item{show_points}{Overlay observations where meaningful.}
\item{optimum}{Optional optimum overlay.}
\item{scale}{For GLM surfaces, response or link scale.}
\item{uncertainty}{Object returned by \code{rsm_optimum_ci()}.}
\item{conf}{Confidence level.}
\item{slice_factor}{Factor varied across slices.}
\item{values}{Slice values.}
}
\description{Uses the common prediction interface so contours, heat maps, 3-D surfaces, profiles and perturbation plots work for polynomial, GLM, nonlinear and expert surrogate models. Design-variance, FDS/VDG and related diagnostics remain tied to design-aware polynomial models.}
\examples{
## Example 1: classical polynomial contour
d <- expand.grid(x1=seq(-1,1,length.out=7),x2=seq(-1,1,length.out=7))
d$y <- 8-d$x1^2-.5*d$x2^2
f <- rsm_fit(d,"y",c("x1","x2"))
rsm_plot(f,"contour")

## Example 2: GLM heat map
d$count <- rpois(nrow(d),exp(2-.2*d$x1^2-.15*d$x2^2))
g <- rsm_glm_fit(d,"count",c("x1","x2"),family=poisson())
rsm_plot(g,"heatmap")

## Example 3: nonlinear contour
n <- transform(expand.grid(N=seq(10,150,length.out=7),P=seq(5,80,length.out=7)),
  z=10*N/(30+N)*P/(20+P))
nl <- rsm_nonlinear_fit(n,"z",c("N","P"),"michaelis_menten2",
  start=c(A=10,K1=30,K2=20),engine="nls")
rsm_plot(nl,"contour")
}
