#' Cross-validation respecting optional experimental groups
# internal legacy implementation retained for cross-checking
.rf_cv_lm_legacy <- function(object, folds = 5, repeats = 1, group = NULL, seed = 123) {
  if (!inherits(object, "rsmFlow_fit")) .rf_stop("object must be an rsmFlow_fit.")
  dat <- object$data; n <- nrow(dat)
  if (folds < 2) .rf_stop("folds must be at least 2.")
  set.seed(seed)
  group_vec <- NULL
  if (!is.null(group)) {
    if (length(group) == 1L && is.character(group) && group %in% names(dat)) group_vec <- dat[[group]] else if (length(group) == n) group_vec <- group else .rf_stop("group must be a column name or a vector with one value per row.")
  } else {
    .rf_warn("Ungrouped random cross-validation is supplementary in designed experiments; use group= when blocks, experimental units, or repeated structures must remain intact.")
  }
  allpred <- list(); idx <- 1L
  for (r in seq_len(repeats)) {
    if (is.null(group_vec)) {
      fold_id <- sample(rep(seq_len(folds), length.out=n))
    } else {
      ug <- unique(group_vec); gf <- sample(rep(seq_len(min(folds,length(ug))), length.out=length(ug)))
      fold_id <- gf[match(group_vec, ug)]
    }
    for (f in sort(unique(fold_id))) {
      train <- droplevels(dat[fold_id != f,,drop=FALSE]); test <- dat[fold_id == f,,drop=FALSE]
      ff <- try(rsm_fit(train, object$response, object$factors, object$order, object$block, object$estimator, bounds=object$bounds, coding=object$coding), silent=TRUE)
      if (inherits(ff,"try-error")) next
      pr <- try(stats::predict(ff$model, newdata=test), silent=TRUE)
      if (inherits(pr,"try-error")) next
      allpred[[idx]] <- data.frame(repeat_id=r, fold=f, observed=test[[object$response]], predicted=as.numeric(pr)); idx <- idx+1L
    }
  }
  pred <- do.call(rbind, allpred)
  if (is.null(pred) || !nrow(pred)) .rf_stop("No cross-validation fold could be fitted successfully.")
  e <- pred$observed-pred$predicted
  metrics <- c(RMSE=sqrt(mean(e^2)), MAE=mean(abs(e)), R2=1-sum(e^2)/sum((pred$observed-mean(pred$observed))^2))
  list(metrics=metrics, predictions=pred, grouped=!is.null(group_vec), group=group)
}

#' Stability of bootstrap optimum coordinates
# internal legacy implementation retained for cross-checking
.rf_optimum_stability_lm_legacy <- function(uncertainty, fit, tolerance = 0.10) {
  if (is.null(uncertainty$bootstrap)) .rf_stop("uncertainty must be an object returned by rsm_optimum_ci().")
  if (!inherits(fit,"rsmFlow_fit")) .rf_stop("fit must be an rsmFlow_fit.")
  B <- uncertainty$bootstrap
  factors <- fit$factors
  est <- uncertainty$estimate[factors]
  ranges <- pmax(fit$bounds$upper-fit$bounds$lower, .Machine$double.eps)
  D <- sweep(as.matrix(B[,factors,drop=FALSE]),2,as.numeric(est),"-")
  D <- sweep(D,2,ranges,"/")
  dist <- sqrt(rowSums(D^2))
  ref <- .rf_predict_scalar(fit, as.numeric(est))
  pred_under_fit <- apply(B[,factors,drop=FALSE],1,function(z) .rf_predict_scalar(fit,z))
  loss <- abs(ref-pred_under_fit)/max(abs(ref),.Machine$double.eps)
  list(
    tolerance=tolerance,
    probability_within_standardized_radius=mean(dist <= tolerance),
    standardized_distance_quantiles=stats::quantile(dist,c(.5,.8,.9,.95)),
    response_loss_quantiles=stats::quantile(loss,c(.5,.8,.9,.95)),
    interpretation="Stability is reported in factor-range standardized distance from the estimated optimum and relative fitted-response loss."
  )
}
