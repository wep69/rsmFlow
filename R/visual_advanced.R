#' One-factor response profile with other factors held fixed
#' @export
rsm_profile <- function(object, factor, at = NULL, n = 100, interval = c("confidence", "none"), level = 0.95) {
  interval <- match.arg(interval)
  if (!.rf_model_supported(object)) .rf_stop("object must be a supported rsmFlow model.")
  if (!factor %in% object$factors) .rf_stop("factor must be one of the fitted quantitative factors.")
  other <- setdiff(object$factors, factor)
  if (is.null(at)) at <- setNames(as.list((object$bounds$lower[other]+object$bounds$upper[other])/2), other)
  g <- data.frame(x = seq(object$bounds$lower[[factor]], object$bounds$upper[[factor]], length.out=n))
  names(g) <- factor
  for (z in other) g[[z]] <- at[[z]] %||% mean(c(object$bounds$lower[[z]], object$bounds$upper[[z]]))
  g <- g[, object$factors, drop=FALSE]
  if (!is.null(object$block)) g[[object$block]] <- object$data[[object$block]][1]
  if (interval == "confidence") {
    pr <- try(.rf_predict_mean(object, g, se.fit=TRUE, level=level), silent=TRUE)
    if (!inherits(pr,"try-error") && is.list(pr) && all(is.finite(pr$se.fit))) {
      z <- stats::qnorm((1+level)/2)
      out <- data.frame(g[,object$factors,drop=FALSE], predicted=pr$fit, lower=pr$fit-z*pr$se.fit, upper=pr$fit+z*pr$se.fit)
    } else out <- data.frame(g[,object$factors,drop=FALSE], predicted=.rf_predict_mean(object,g))
  } else out <- data.frame(g[,object$factors,drop=FALSE], predicted=.rf_predict_mean(object,g))
  attr(out,"profile_factor") <- factor
  class(out) <- c("rsmFlow_profile",class(out))
  out
}

#' Perturbation profiles around a reference factor combination
#' @export
rsm_perturbation <- function(object, reference = NULL, n = 100, standardized = TRUE) {
  if (!.rf_model_supported(object)) .rf_stop("object must be a supported rsmFlow model.")
  if (is.null(reference)) reference <- (object$bounds$lower+object$bounds$upper)/2
  reference <- as.numeric(reference); names(reference) <- object$factors
  if (length(reference)!=length(object$factors)) .rf_stop("reference must contain one value per factor.")
  rows <- lapply(seq_along(object$factors), function(j) {
    f <- object$factors[j]
    vals <- seq(object$bounds$lower[j],object$bounds$upper[j],length.out=n)
    P <- matrix(rep(reference, each=n),nrow=n); P[,j] <- vals
    pred <- apply(P,1,function(x).rf_predict_scalar(object,x))
    axis <- if (standardized) (vals-reference[j])/max((object$bounds$upper[j]-object$bounds$lower[j])/2,.Machine$double.eps) else vals
    data.frame(factor=f, axis=axis, natural_value=vals, predicted=pred, stringsAsFactors=FALSE)
  })
  out <- do.call(rbind,rows)
  attr(out,"reference") <- reference
  attr(out,"standardized") <- standardized
  class(out) <- c("rsmFlow_perturbation",class(out))
  out
}

#' Overlay feasibility constraints from multiple response surfaces
#' @export
rsm_overlaid_contour <- function(fits, constraints, x = NULL, y = NULL, at = NULL, n = 100) {
  if (!is.list(fits) || length(fits)<2L || !all(vapply(fits,.rf_model_supported,logical(1)))) .rf_stop("fits must contain at least two supported rsmFlow model objects.")
  factors <- fits[[1]]$factors
  if (!all(vapply(fits,function(z) identical(z$factors,factors),logical(1)))) .rf_stop("All fits must use the same factors in the same order.")
  if (length(constraints)!=length(fits)) .rf_stop("constraints must match fits.")
  if (is.null(x)) x <- factors[1]; if (is.null(y)) y <- factors[2]
  other <- setdiff(factors,c(x,y))
  if (is.null(at)) at <- setNames(as.list((fits[[1]]$bounds$lower[other]+fits[[1]]$bounds$upper[other])/2),other)
  xs <- seq(fits[[1]]$bounds$lower[[x]],fits[[1]]$bounds$upper[[x]],length.out=n)
  ys <- seq(fits[[1]]$bounds$lower[[y]],fits[[1]]$bounds$upper[[y]],length.out=n)
  g <- expand.grid(xs,ys,KEEP.OUT.ATTRS=FALSE); names(g)<-c(x,y)
  for(z in other) g[[z]] <- at[[z]] %||% mean(c(fits[[1]]$bounds$lower[[z]],fits[[1]]$bounds$upper[[z]]))
  g <- g[,factors,drop=FALSE]
  feasible <- rep(TRUE,nrow(g))
  for(i in seq_along(fits)) {
    nd <- g; if(!is.null(fits[[i]]$block)) nd[[fits[[i]]$block]] <- fits[[i]]$data[[fits[[i]]$block]][1]
    pr <- .rf_predict_mean(fits[[i]],nd); g[[paste0("response",i)]] <- pr
    cst <- constraints[[i]]; goal <- cst$goal %||% "interval"
    ok <- if(goal=="max") pr >= cst$low else if(goal=="min") pr <= cst$high else if(goal=="target") abs(pr-cst$target) <= (cst$tolerance %||% 0) else pr >= cst$low & pr <= cst$high
    feasible <- feasible & ok
  }
  g$.feasible <- feasible
  attr(g,"x")<-x; attr(g,"y")<-y; attr(g,"constraints")<-constraints
  class(g)<-c("rsmFlow_overlaid",class(g)); g
}

#' Desirability surface for multiple fitted responses
#' @export
rsm_desirability_surface <- function(fits, goals, limits, importance = NULL,
                                     x = NULL, y = NULL, at = NULL, n = 100) {
  if (!is.list(fits) || length(fits)<2L || !all(vapply(fits,.rf_model_supported,logical(1)))) .rf_stop("fits must contain at least two supported rsmFlow model objects.")
  factors <- fits[[1]]$factors
  if (!all(vapply(fits,function(z) identical(z$factors,factors),logical(1)))) .rf_stop("All fits must use the same factors.")
  if(length(goals)!=length(fits)||length(limits)!=length(fits)) .rf_stop("goals and limits must match fits.")
  if(is.null(importance)) importance<-rep(1,length(fits))
  if(length(importance)!=length(fits) || any(!is.finite(importance)) || any(importance<0) || sum(importance)<=0) .rf_stop("importance must contain non-negative finite weights with positive total weight.")
  for(i in seq_along(limits)) if(is.null(limits[[i]]$low) || is.null(limits[[i]]$high) || limits[[i]]$high<=limits[[i]]$low) .rf_stop("Each limits[[i]] must define high > low.")
  if(is.null(x)) x<-factors[1]; if(is.null(y)) y<-factors[2]
  other<-setdiff(factors,c(x,y)); if(is.null(at)) at<-setNames(as.list((fits[[1]]$bounds$lower[other]+fits[[1]]$bounds$upper[other])/2),other)
  xs<-seq(fits[[1]]$bounds$lower[[x]],fits[[1]]$bounds$upper[[x]],length.out=n); ys<-seq(fits[[1]]$bounds$lower[[y]],fits[[1]]$bounds$upper[[y]],length.out=n)
  g<-expand.grid(xs,ys,KEEP.OUT.ATTRS=FALSE); names(g)<-c(x,y); for(z in other) g[[z]]<-at[[z]] %||% mean(c(fits[[1]]$bounds$lower[[z]],fits[[1]]$bounds$upper[[z]])); g<-g[,factors,drop=FALSE]
  D<-matrix(NA_real_,nrow(g),length(fits))
  for(i in seq_along(fits)) {
    nd<-g; if(!is.null(fits[[i]]$block)) nd[[fits[[i]]$block]]<-fits[[i]]$data[[fits[[i]]$block]][1]
    pr<-.rf_predict_mean(fits[[i]],nd); lim<-limits[[i]]
    D[,i]<-rsm_desirability(pr,goals[[i]],lim$low,lim$high,lim$target %||% NULL,lim$shape %||% 1)
  }
  zero<-apply(D<=0,1,any); g$desirability<-0; ok<-!zero; if(any(ok)) g$desirability[ok]<-exp(rowSums(sweep(log(D[ok,,drop=FALSE]),2,importance,"*"))/sum(importance))
  attr(g,"x")<-x; attr(g,"y")<-y; class(g)<-c("rsmFlow_desirability_surface",class(g)); g
}

#' Plot a Pareto solution set
#' @export
rsm_plot_pareto <- function(pareto, response_x = NULL, response_y = NULL) {
  resp <- grep("^response",names(pareto),value=TRUE)
  if(length(resp)<2L) .rf_stop("pareto must contain at least two response columns returned by rsm_pareto().")
  if(is.null(response_x)) response_x<-resp[1]; if(is.null(response_y)) response_y<-resp[2]
  if(!requireNamespace("ggplot2",quietly=TRUE)) return(pareto[,c(response_x,response_y),drop=FALSE])
  ggplot2::ggplot(pareto,ggplot2::aes_string(x=response_x,y=response_y))+ggplot2::geom_point()+ggplot2::labs(title="Pareto solution set")+ggplot2::theme_minimal()
}

# S3 plotting helpers ------------------------------------------------------
#' @export
plot.rsmFlow_profile <- function(x, ...) {
  f<-attr(x,"profile_factor"); if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  p<-ggplot2::ggplot(x,ggplot2::aes_string(x=f,y="predicted"))+ggplot2::geom_line()+ggplot2::theme_minimal()+ggplot2::labs(y="Predicted response",title=paste("Response profile:",f))
  if(all(c("lower","upper")%in%names(x))) p<-p+ggplot2::geom_ribbon(ggplot2::aes(ymin=lower,ymax=upper),alpha=.15)
  p
}
#' @export
plot.rsmFlow_perturbation <- function(x, ...) {
  if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  ggplot2::ggplot(x,ggplot2::aes(x=axis,y=predicted,group=factor,linetype=factor))+ggplot2::geom_line()+ggplot2::labs(x=if(attr(x,"standardized")) "Standardized displacement" else "Factor value",y="Predicted response",title="Perturbation plot")+ggplot2::theme_minimal()
}
#' @export
plot.rsmFlow_fds <- function(x, ...) {
  if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  ggplot2::ggplot(x,ggplot2::aes(x=fraction,y=scaled_prediction_variance))+ggplot2::geom_line()+ggplot2::labs(x="Fraction of design space",y="Scaled prediction variance",title="FDS curve")+ggplot2::theme_minimal()
}
#' @export
plot.rsmFlow_vdg <- function(x, ...) {
  if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  long<-rbind(data.frame(radius=x$radius,statistic="minimum",spv=x$min_spv),data.frame(radius=x$radius,statistic="mean",spv=x$mean_spv),data.frame(radius=x$radius,statistic="maximum",spv=x$max_spv))
  ggplot2::ggplot(long,ggplot2::aes(x=radius,y=spv,linetype=statistic))+ggplot2::geom_line()+ggplot2::labs(y="Scaled prediction variance",title="Variance dispersion graph")+ggplot2::theme_minimal()
}
#' @export
plot.rsmFlow_overlaid <- function(x, ...) {
  xx<-attr(x,"x"); yy<-attr(x,"y"); if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  ggplot2::ggplot(x,ggplot2::aes_string(x=xx,y=yy,fill=".feasible"))+ggplot2::geom_raster()+ggplot2::labs(fill="Feasible",title="Overlaid response constraints")+ggplot2::theme_minimal()
}
#' @export
plot.rsmFlow_desirability_surface <- function(x, ...) {
  xx<-attr(x,"x"); yy<-attr(x,"y"); if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  ggplot2::ggplot(x,ggplot2::aes_string(x=xx,y=yy,fill="desirability"))+ggplot2::geom_raster()+ggplot2::geom_contour(ggplot2::aes(z=desirability))+ggplot2::labs(fill="Desirability",title="Combined desirability surface")+ggplot2::theme_minimal()
}
#' @export
plot.rsmFlow_slices <- function(x, ...) {
  xx<-attr(x,"x"); yy<-attr(x,"y"); sf<-attr(x,"slice_factor"); if(!requireNamespace("ggplot2",quietly=TRUE)) return(invisible(x))
  ggplot2::ggplot(x,ggplot2::aes_string(x=xx,y=yy,fill="predicted"))+ggplot2::geom_raster()+ggplot2::geom_contour(ggplot2::aes(z=predicted))+ggplot2::facet_wrap(stats::as.formula(paste0("~`",sf,"`")),scales="fixed")+ggplot2::theme_minimal()+ggplot2::labs(fill="Predicted",title=paste("Response slices by",sf))
}
