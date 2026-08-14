#' Plot fitted response surfaces and diagnostics
# internal core
.rf_plot_lm <- function(object, type = c("contour", "heatmap", "surface", "prediction_variance", "residuals", "qq", "leverage", "cooks", "term_correlation", "design", "fds", "vdg", "canonical", "profile", "perturbation"),
                     x = NULL, y = NULL, at = NULL, n = 60, interactive = FALSE,
                     show_points = TRUE, optimum = NULL) {
  type <- match.arg(type)
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  if (type == "fds") return(plot(rsm_fds(object)))
  if (type == "vdg") return(plot(rsm_vdg(object)))
  if (type == "profile") {
    if (is.null(x)) x <- object$factors[1]
    return(plot(rsm_profile(object, x, at=at)))
  }
  if (type == "perturbation") return(plot(rsm_perturbation(object)))
  if (type %in% c("qq","leverage","cooks","term_correlation","design")) {
    if (!requireNamespace("ggplot2", quietly=TRUE)) {
      if (type=="term_correlation") return(rsm_orthogonality(object)$correlation)
      return(rsm_diagnostics(object))
    }
    if (type=="qq") {
      d<-data.frame(residual=stats::residuals(object$model))
      return(ggplot2::ggplot(d,ggplot2::aes(sample=residual))+ggplot2::stat_qq()+ggplot2::stat_qq_line()+ggplot2::theme_minimal()+ggplot2::labs(title="Normal Q-Q plot"))
    }
    if (type %in% c("leverage","cooks")) {
      dg<-rsm_diagnostics(object); d<-data.frame(index=seq_len(dg$n),value=if(type=="leverage") dg$leverage else dg$cooks_distance)
      return(ggplot2::ggplot(d,ggplot2::aes(x=index,y=value))+ggplot2::geom_point()+ggplot2::geom_segment(ggplot2::aes(xend=index,yend=0))+ggplot2::theme_minimal()+ggplot2::labs(y=if(type=="leverage") "Leverage" else "Cook's distance",title=if(type=="leverage") "Leverage by observation" else "Cook's distance by observation"))
    }
    if (type=="term_correlation") {
      C<-rsm_orthogonality(object)$correlation; dd<-expand.grid(term1=colnames(C),term2=colnames(C),stringsAsFactors=FALSE); dd$correlation<-as.vector(C)
      return(ggplot2::ggplot(dd,ggplot2::aes(x=term1,y=term2,fill=correlation))+ggplot2::geom_tile()+ggplot2::theme_minimal()+ggplot2::theme(axis.text.x=ggplot2::element_text(angle=45,hjust=1))+ggplot2::labs(title="Model-term correlation"))
    }
    if (is.null(x)) x<-object$factors[1]; if(is.null(y)) y<-object$factors[2]
    return(ggplot2::ggplot(object$data,ggplot2::aes_string(x=x,y=y))+ggplot2::geom_point()+ggplot2::theme_minimal()+ggplot2::labs(title="Experimental design projection"))
  }
  if (type == "residuals") {
    d <- data.frame(fitted = stats::fitted(object$model), residual = stats::residuals(object$model))
    if (!requireNamespace("ggplot2", quietly = TRUE)) return(d)
    p <- ggplot2::ggplot(d, ggplot2::aes(x = fitted, y = residual)) +
      ggplot2::geom_point() + ggplot2::geom_hline(yintercept = 0, linetype = 2) +
      ggplot2::labs(x = "Fitted", y = "Residual", title = "Residuals versus fitted values") + ggplot2::theme_minimal()
    if (interactive && requireNamespace("plotly", quietly = TRUE)) return(plotly::ggplotly(p))
    return(p)
  }
  if (is.null(x)) x <- object$factors[1]
  if (is.null(y)) y <- object$factors[2]
  if (!all(c(x,y) %in% object$factors)) .rf_stop("x and y must be fitted quantitative factors.")
  other <- setdiff(object$factors, c(x,y))
  if (is.null(at)) at <- setNames(as.list((object$bounds$lower[other] + object$bounds$upper[other])/2), other)
  xs <- seq(object$bounds$lower[[x]], object$bounds$upper[[x]], length.out = n)
  ys <- seq(object$bounds$lower[[y]], object$bounds$upper[[y]], length.out = n)
  grid <- expand.grid(xs, ys, KEEP.OUT.ATTRS = FALSE); names(grid) <- c(x,y)
  for (z in other) grid[[z]] <- at[[z]] %||% mean(c(object$bounds$lower[[z]], object$bounds$upper[[z]]))
  grid <- grid[, object$factors, drop = FALSE]
  if (!is.null(object$block)) grid[[object$block]] <- object$data[[object$block]][1]
  if (type == "prediction_variance") {
    pv <- rsm_prediction_variance(object, grid, scaled = TRUE)
    grid$value <- pv$prediction_variance
  } else grid$value <- as.numeric(stats::predict(object$model, newdata = grid))

  if (type == "canonical") {
    if (!requireNamespace("ggplot2",quietly=TRUE)) return(list(grid=grid,canonical=rsm_canonical(object)))
    ca<-rsm_canonical(object)
    p<-ggplot2::ggplot(grid,ggplot2::aes_string(x=x,y=y))+ggplot2::geom_contour(ggplot2::aes(z=value))+ggplot2::theme_minimal()+ggplot2::labs(title=paste("Canonical geometry:",ca$nature))
    if(all(is.finite(ca$stationary_point[c(x,y)]))) {
      sp<-data.frame(xx=ca$stationary_point[[x]],yy=ca$stationary_point[[y]])
      p<-p+ggplot2::geom_point(data=sp,ggplot2::aes(x=xx,y=yy),inherit.aes=FALSE,shape=4,size=4,stroke=1.2)
      scl<-0.3*min(diff(range(xs)),diff(range(ys)))
      seg<-do.call(rbind,lapply(seq_len(ncol(ca$eigenvectors)),function(j) data.frame(x0=sp$xx-scl*ca$eigenvectors[x,j],x1=sp$xx+scl*ca$eigenvectors[x,j],y0=sp$yy-scl*ca$eigenvectors[y,j],y1=sp$yy+scl*ca$eigenvectors[y,j],axis=paste0("C",j))))
      p<-p+ggplot2::geom_segment(data=seg,ggplot2::aes(x=x0,y=y0,xend=x1,yend=y1,linetype=axis),inherit.aes=FALSE)
    }
    if(interactive && requireNamespace("plotly",quietly=TRUE)) return(plotly::ggplotly(p))
    return(p)
  }

  if (type == "surface" && interactive && requireNamespace("plotly", quietly = TRUE)) {
    z <- matrix(grid$value, nrow = n, ncol = n)
    p <- plotly::plot_ly(x = xs, y = ys, z = t(z), type = "surface")
    p <- plotly::layout(p, scene = list(xaxis = list(title = x), yaxis = list(title = y), zaxis = list(title = object$response)))
    return(p)
  }
  if (type == "surface" && !interactive) {
    z <- matrix(grid$value, nrow=n, ncol=n)
    graphics::persp(xs, ys, z, xlab=x, ylab=y, zlab=object$response, ticktype="detailed", theta=35, phi=25)
    return(invisible(list(x=xs,y=ys,z=z,grid=grid)))
  }
  if (!requireNamespace("ggplot2", quietly = TRUE)) return(grid)
  p <- ggplot2::ggplot(grid, ggplot2::aes_string(x = x, y = y))
  if (type == "contour") p <- p + ggplot2::geom_contour(ggplot2::aes(z = value))
  else p <- p + ggplot2::geom_raster(ggplot2::aes(fill = value), interpolate = TRUE) + ggplot2::geom_contour(ggplot2::aes(z = value))
  if (show_points && !length(other)) p <- p + ggplot2::geom_point(data = object$data, ggplot2::aes_string(x = x, y = y), inherit.aes = FALSE)
  if (show_points && length(other)) .rf_warn("Observed points are not overlaid on a conditional slice with additional factors, because observations may have different held-factor values. Use rsm_slices() or rsm_profile() for explicit conditional displays.")
  if (!is.null(optimum) && inherits(optimum, "rsmFlow_optimum")) {
    op <- as.data.frame(as.list(optimum$solution))
    p <- p + ggplot2::geom_point(data = op, ggplot2::aes_string(x = x, y = y), inherit.aes = FALSE, shape = 4, size = 4, stroke = 1.2)
  }
  p <- p + ggplot2::labs(fill = if (type == "prediction_variance") "Scaled prediction variance" else object$response,
                          title = if (type == "prediction_variance") "Prediction-variance map" else "Response surface") + ggplot2::theme_minimal()
  if (interactive && requireNamespace("plotly", quietly = TRUE)) return(plotly::ggplotly(p))
  p
}

#' Generate sliced two-dimensional surfaces for models with more than two factors
#' @export
rsm_slices <- function(object, x = NULL, y = NULL, slice_factor = NULL, values = NULL, n = 50) {
  if (!.rf_model_supported(object)) .rf_stop("object must be a supported rsmFlow model.")
  if (length(object$factors) < 3L) .rf_stop("Sliced surfaces are most useful with three or more factors.")
  if (is.null(x)) x <- object$factors[1]; if (is.null(y)) y <- object$factors[2]
  if (is.null(slice_factor)) slice_factor <- setdiff(object$factors, c(x,y))[1]
  if (is.null(values)) values <- seq(object$bounds$lower[[slice_factor]], object$bounds$upper[[slice_factor]], length.out = 5)
  out <- do.call(rbind, lapply(values, function(v) {
    xs <- seq(object$bounds$lower[[x]], object$bounds$upper[[x]], length.out = n)
    ys <- seq(object$bounds$lower[[y]], object$bounds$upper[[y]], length.out = n)
    g <- expand.grid(xs, ys, KEEP.OUT.ATTRS = FALSE); names(g) <- c(x,y)
    other <- setdiff(object$factors, c(x,y,slice_factor))
    g[[slice_factor]] <- v
    for (z in other) g[[z]] <- mean(c(object$bounds$lower[[z]], object$bounds$upper[[z]]))
    g <- g[, object$factors, drop = FALSE]
    g$predicted <- .rf_predict_mean(object, g)
    g[[slice_factor]] <- v
    g$.slice <- v
    g
  }))
  attr(out,"x")<-x; attr(out,"y")<-y; attr(out,"slice_factor")<-slice_factor
  class(out)<-c("rsmFlow_slices",class(out)); out
}

#' Pedagogical explanation of an rsmFlow fit
#' @export
rsm_explain <- function(object) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  a <- rsm_design_audit(object)
  ca <- if (object$order == 2L && a$estimable) try(rsm_canonical(object), silent = TRUE) else NULL
  lof <- if (object$estimator == "ols") rsm_lack_of_fit(object) else list(available = FALSE)
  lines <- c(
    paste0("Model: hierarchical order-", object$order, " response surface with ", length(object$factors), " quantitative factors."),
    paste0("Design estimability: ", if (a$estimable) "full rank" else "not full rank", "; condition number = ", signif(a$condition_number_scaled, 4), "."),
    paste0("Maximum absolute correlation among model terms = ", signif(a$orthogonality$max_abs_correlation, 4), "."),
    if (lof$available) paste0("Lack-of-fit p-value = ", signif(lof$lack_of_fit[["p.value"]], 4), ".") else "Formal lack-of-fit test is unavailable because replicated design points or degrees of freedom are insufficient.",
    if (!is.null(ca) && !inherits(ca, "try-error")) paste0("Canonical classification: ", ca$nature, "; stationary point inside declared region: ", ca$inside_region, ".") else NULL,
    "Optimization should be reported with declared bounds and, when inference matters, uncertainty for the optimum rather than only a point estimate."
  )
  structure(lines, class = c("rsmFlow_explanation", "character"))
}

#' Plot bootstrap uncertainty in optimum coordinates
#' @export
rsm_plot_optimum_uncertainty <- function(uncertainty, x = NULL, y = NULL, conf = NULL) {
  if (is.null(uncertainty$bootstrap)) .rf_stop("uncertainty must come from rsm_optimum_ci().")
  factors <- setdiff(names(uncertainty$bootstrap), "predicted")
  if (length(factors) < 2L) .rf_stop("At least two factor coordinates are required.")
  if (is.null(x)) x <- factors[1]; if (is.null(y)) y <- factors[2]
  reg <- rsm_optimum_region(uncertainty, c(x,y), conf=conf)
  if (!requireNamespace("ggplot2",quietly=TRUE)) return(list(samples=uncertainty$bootstrap[,c(x,y)], region=reg))
  est <- as.data.frame(as.list(uncertainty$estimate[c(x,y)]))
  p <- ggplot2::ggplot(uncertainty$bootstrap, ggplot2::aes_string(x=x,y=y)) +
    ggplot2::geom_point(alpha=.25) +
    ggplot2::geom_path(data=reg$boundary, ggplot2::aes_string(x=x,y=y), inherit.aes=FALSE, linewidth=1) +
    ggplot2::geom_point(data=est, ggplot2::aes_string(x=x,y=y), inherit.aes=FALSE, shape=4, size=4, stroke=1.2) +
    ggplot2::labs(title=paste0(round(100*reg$conf), "% approximate joint bootstrap optimum region")) +
    ggplot2::theme_minimal()
  p
}
