# Cross-engine comparisons -------------------------------------------------

#' Compare fitted response-surface engines on compatible summaries
#' @export
rsm_compare_engines <- function(...) {
  fits <- list(...)
  if (length(fits)==1L && is.list(fits[[1]]) && !.rf_model_supported(fits[[1]])) fits <- fits[[1]]
  if (!length(fits) || !all(vapply(fits,.rf_model_supported,logical(1)))) .rf_stop("Provide rsmFlow model objects.")
  rows <- lapply(seq_along(fits),function(i){
    z<-fits[[i]]; obs<-z$data[[z$response]]; pred<-.rf_fitted_values(z); e<-obs-pred
    ll<-tryCatch(as.numeric(stats::logLik(z$model)),error=function(e)NA_real_)
    aic<-tryCatch(stats::AIC(z$model),error=function(e)NA_real_); bic<-tryCatch(stats::BIC(z$model),error=function(e)NA_real_)
    if(inherits(z,"rsmFlow_glm") && grepl("^quasi",stats::family(z$model)$family)){aic<-NA_real_;bic<-NA_real_}
    nm <- names(fits)[i]; if (is.null(nm) || is.na(nm) || !nzchar(nm)) nm <- paste0("model",i)
    data.frame(name=nm,kind=.rf_model_kind(z),engine=z$engine %||% z$estimator %||% "rsmFlow",
               RMSE=sqrt(mean(e^2,na.rm=TRUE)),MAE=mean(abs(e),na.rm=TRUE),logLik=ll,AIC=aic,BIC=bic,
               converged=if(inherits(z,"rsmFlow_nonlinear")) rsm_nonlinear_diagnostics(z)$converged else TRUE,
               stringsAsFactors=FALSE)
  })
  do.call(rbind,rows)
}

#' Compare optimum coordinates and predictions from multiple model engines
#' @export
rsm_compare_optima <- function(...) {
  opts <- list(...)
  if (length(opts) == 1L && is.list(opts[[1]]) && is.null(opts[[1]]$solution)) opts <- opts[[1]]
  rows <- lapply(seq_along(opts), function(i) {
    z <- opts[[i]]
    if (is.null(z$solution)) .rf_stop("Each object must contain an optimum solution.")
    nm <- names(opts)[i]
    if (is.null(nm) || is.na(nm) || !nzchar(nm)) nm <- paste0("optimum", i)
    coords <- as.data.frame(as.list(z$solution), check.names = FALSE)
    coords$name <- nm
    coords$predicted <- z$predicted %||% z$predicted_response
    coords$method <- z$method %||% NA_character_
    coords[, c("name", setdiff(names(coords), "name")), drop = FALSE]
  })
  do.call(rbind, rows)
}
