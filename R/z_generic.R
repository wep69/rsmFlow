# Unified public API across Gaussian, GLM, nonlinear and surrogate models ----

#' Unified lack-of-fit assessment
#' @export
rsm_lack_of_fit <- function(object, ...) {
  if (inherits(object,"rsmFlow_glm")) return(rsm_glm_lack_of_fit(object))
  if (inherits(object,"rsmFlow_fit")) return(.rf_lm_lack_of_fit(object))
  if (inherits(object,"rsmFlow_nonlinear")) return(list(available=FALSE, reason="A classical replicated-cell lack-of-fit decomposition is not automatically reported for nonlinear models; compare nested scientifically meaningful nonlinear structures, residual patterns, and predictive performance."))
  .rf_stop("Lack-of-fit assessment is unavailable for this object class.")
}

#' Unified diagnostics
#' @export
rsm_diagnostics <- function(object, ...) {
  if (inherits(object,"rsmFlow_glm")) return(rsm_glm_diagnostics(object))
  if (inherits(object,"rsmFlow_nonlinear")) return(rsm_nonlinear_diagnostics(object))
  if (inherits(object,"rsmFlow_fit")) return(.rf_lm_diagnostics(object))
  if (inherits(object,"rsmFlow_surrogate")) {
    e <- object$data[[object$response]] - .rf_fitted_values(object)
    return(list(engine=object$engine,method=object$method,RMSE=sqrt(mean(e^2)),MAE=mean(abs(e)),residuals=e))
  }
  .rf_stop("Unsupported object class.")
}

#' Unified canonical analysis
#' @export
rsm_canonical <- function(object, tol = 1e-7, ...) {
  if (inherits(object,"rsmFlow_glm")) return(rsm_glm_canonical(object,tol=tol))
  if (inherits(object,"rsmFlow_fit")) return(.rf_canonical_lm(object,tol=tol))
  if (inherits(object,"rsmFlow_nonlinear")) .rf_stop("Canonical polynomial analysis is not generally defined for nonlinear surfaces. Use rsm_optimize(), rsm_profile(), rsm_perturbation(), and response-scale numerical geometry instead.")
  .rf_stop("Canonical analysis is unavailable for this object class.")
}

#' Unified bounded/global optimization for rsmFlow models
#' @export
rsm_optimize <- function(object, goal = c("max","min","target"),
                         method = c("hybrid","L-BFGS-B","GA","grid","analytic","all"),
                         target = NULL, bounds = NULL, seed = 123,
                         grid_n = 31, ga_control = list(popSize=80,maxiter=500,run=100),
                         scale = c("response","link")) {
  goal<-match.arg(goal); method<-match.arg(method); scale<-match.arg(scale)
  if (!.rf_model_supported(object)) .rf_stop("object must be a supported rsmFlow model.")
  if (scale=="link" && !inherits(object,"rsmFlow_glm")) .rf_stop("scale='link' is available only for rsmFlow_glm objects.")
  if(goal=="target"&&is.null(target)) .rf_stop("target= is required when goal='target'.")
  b<-if(is.null(bounds)) object$bounds else .rf_bounds(object$data,object$factors,bounds); lower<-b$lower; upper<-b$upper
  set.seed(seed)
  score<-function(x){y<-.rf_predict_scalar(object,x,scale=scale); if(goal=="max") y else if(goal=="min") -y else -abs(y-target)}
  rows<-list(); add<-function(name,x){y<-.rf_predict_scalar(object,x,scale=scale);rows[[length(rows)+1L]]<<-c(method=name,setNames(as.numeric(x),object$factors),predicted=y,score=score(x))}
  if(method%in%c("analytic","all")){
    if(inherits(object,c("rsmFlow_fit","rsmFlow_glm")) && object$order==2L){ca<-try(rsm_canonical(object),silent=TRUE);if(!inherits(ca,"try-error")&&all(is.finite(ca$stationary_point))&&all(ca$stationary_point>=lower&ca$stationary_point<=upper)&&((goal=="max"&&ca$nature=="maximum")||(goal=="min"&&ca$nature=="minimum")))add("analytic_stationary",ca$stationary_point)}
    else if(method=="analytic") .rf_stop("Analytic stationary optimization is limited to second-order polynomial/GLM surfaces.")
  }
  if(method%in%c("grid","all","hybrid")){grid<-.rf_design_grid(b,n=grid_n,max_points=150000L);vals<-apply(grid[,object$factors,drop=FALSE],1,score);xg<-as.numeric(grid[which.max(vals),object$factors,drop=TRUE]);add("grid",xg)} else xg<-(lower+upper)/2
  if(method%in%c("L-BFGS-B","all","hybrid")){starts<-rbind((lower+upper)/2,xg);ops<-lapply(seq_len(nrow(starts)),function(i)stats::optim(starts[i,],function(x)-score(x),method="L-BFGS-B",lower=lower,upper=upper));best<-ops[[which.min(vapply(ops,`[[`,numeric(1),"value"))]];add("L-BFGS-B",best$par)}
  if(method%in%c("GA","all","hybrid")){
    if(requireNamespace("GA",quietly=TRUE)){ctrl<-modifyList(list(popSize=80,maxiter=500,run=100),ga_control);ga<-GA::ga(type="real-valued",fitness=score,lower=lower,upper=upper,popSize=ctrl$popSize,maxiter=ctrl$maxiter,run=ctrl$run,monitor=FALSE,seed=seed);xga<-as.numeric(ga@solution[1,]);add("GA",xga);if(method=="hybrid"){lo<-stats::optim(xga,function(x)-score(x),method="L-BFGS-B",lower=lower,upper=upper);add("GA+L-BFGS-B",lo$par)}}
    else if(method=="GA") .rf_stop("Package 'GA' is required for method='GA'.") else .rf_warn("Package 'GA' is unavailable; hybrid optimization used grid + L-BFGS-B only.")
  }
  if(!length(rows)) .rf_stop("No optimization method produced a candidate solution.")
  df<-as.data.frame(do.call(rbind,rows),stringsAsFactors=FALSE,check.names=FALSE);num<-setdiff(names(df),"method");df[num]<-lapply(df[num],as.numeric);i<-which.max(df$score)
  out<-list(solution=setNames(as.numeric(df[i,object$factors]),object$factors),predicted=df$predicted[i],method=df$method[i],goal=goal,target=target,candidates=df,bounds=b,inside_region=TRUE,fit=object,scale=scale);class(out)<-"rsmFlow_optimum";out
}

#' Unified optimum uncertainty by refitting and reoptimization
#' @export
rsm_optimum_ci <- function(object, optimum = NULL, B = 999, conf = 0.95,
                           method = NULL, optimizer = "L-BFGS-B", seed = 123) {
  if(!.rf_model_supported(object) || inherits(object,"rsmFlow_surrogate")) .rf_stop("Bootstrap refit inference requires a Gaussian, GLM, or nonlinear fitted model.")
  if(is.null(method)) {
    if(inherits(object,"rsmFlow_glm")) method<-if(grepl("^quasi",stats::family(object$model)$family)) "coefficient" else "parametric"
    else if(inherits(object,"rsmFlow_nonlinear")) method<-if(identical(object$engine,"gnls")) "coefficient" else "parametric"
    else method<-"residual"
  }
  method<-match.arg(method,c("residual","parametric","case","coefficient"))
  if(method=="residual" && inherits(object,"rsmFlow_glm")) .rf_stop("Residual bootstrap is not the default GLM resampling scheme; use parametric, coefficient, or scientifically justified case resampling.")
  if(method=="parametric" && inherits(object,"rsmFlow_glm") && grepl("^quasi",stats::family(object$model)$family)) .rf_stop("A unique parametric sampling distribution is not defined by a quasi family; use method='coefficient' or a scientifically justified alternative.")
  if(method=="parametric" && inherits(object,"rsmFlow_nonlinear") && identical(object$engine,"gnls")) .rf_stop("Parametric simulation of the fitted gnls variance/correlation structure is not implemented in this development version; use method='coefficient' for asymptotic parameter uncertainty or a justified case sensitivity analysis.")
  if(is.null(optimum)) optimum<-rsm_optimize(object,method=optimizer)
  if(method=="case") .rf_warn("Case bootstrap can disrupt designed-experiment structure; use it as a sensitivity analysis unless case resampling is scientifically justified.")
  set.seed(seed);dat<-object$data;yname<-object$response;fitted<-.rf_fitted_values(object);resid<-.rf_residual_values(object)
  sols<-matrix(NA_real_,B,length(object$factors)+1L);colnames(sols)<-c(object$factors,"predicted");fail<-0L
  for(b in seq_len(B)){
    db<-dat
    if(method=="case") db<-dat[sample(seq_len(nrow(dat)),nrow(dat),replace=TRUE),,drop=FALSE]
    else if(inherits(object,"rsmFlow_glm")&&method=="parametric"){
      sim<-try(stats::simulate(object$model,nsim=1)[[1]],silent=TRUE);if(inherits(sim,"try-error")){fail<-fail+1L;next};if(is.matrix(sim)&&ncol(sim)==2L){den<-rowSums(sim);sim<-ifelse(den>0,sim[,1]/den,NA_real_)};db[[yname]]<-as.numeric(sim)
    } else if(inherits(object,"rsmFlow_nonlinear")&&method=="parametric") {
      sg<-sqrt(sum(resid^2)/max(1,length(resid)-length(stats::coef(object$model))));db[[yname]]<-fitted+stats::rnorm(length(fitted),0,sg)
    } else if(method=="coefficient") {
      cf<-try(stats::coef(object$model),silent=TRUE);V<-try(stats::vcov(object$model),silent=TRUE);if(inherits(cf,"try-error")||inherits(V,"try-error")){fail<-fail+1L;next};draw<-.rf_mvn(1,cf,V)[1,];names(draw)<-names(cf)
      fb<-object
      if(inherits(object,"rsmFlow_glm")) fb$model$coefficients<-draw
      else if(inherits(object,"rsmFlow_nonlinear")) fb$coefficient_override<-draw
      else {fail<-fail+1L;next}
    } else db[[yname]]<-fitted+sample(resid,length(resid),replace=TRUE)
    if(method!="coefficient") {fb<-try(.rf_refit_model(object,db,seed=seed+b),silent=TRUE);if(inherits(fb,"try-error")){fail<-fail+1L;next}}
    ob<-try(rsm_optimize(fb,goal=optimum$goal,method=optimizer,target=optimum$target,bounds=object$bounds,seed=seed+b),silent=TRUE);if(inherits(ob,"try-error")){fail<-fail+1L;next}
    sols[b,]<-c(ob$solution,ob$predicted)
  }
  sols<-sols[stats::complete.cases(sols),,drop=FALSE];if(nrow(sols)<max(30,.5*B)) .rf_warn("A high fraction of bootstrap replicates failed; inspect convergence, estimability, boundaries, or model specification.")
  alpha<-(1-conf)/2;ci<-t(apply(sols,2,stats::quantile,probs=c(alpha,1-alpha),na.rm=TRUE));colnames(ci)<-c("lower","upper")
  inside<-if(nrow(sols))apply(sols[,object$factors,drop=FALSE],1,function(z)all(z>=object$bounds$lower&z<=object$bounds$upper)) else logical(0)
  list(estimate=c(optimum$solution,predicted=optimum$predicted),intervals=ci,bootstrap=as.data.frame(sols),conf=conf,B_requested=B,B_valid=nrow(sols),failures=fail,probability_inside_region=if(length(inside))mean(inside)else NA_real_,method=method,model_kind=.rf_model_kind(object))
}

#' Unified near-optimal region
#' @export
rsm_near_optimal <- function(object,optimum=NULL,tolerance=.05,goal=c("max","min"),n=41,max_points=150000,seed=123){goal<-match.arg(goal);if(!.rf_model_supported(object)) .rf_stop("Unsupported model.");if(is.null(optimum))optimum<-rsm_optimize(object,goal=goal,method="hybrid",seed=seed);set.seed(seed);grid<-.rf_design_grid(object$bounds,n=n,max_points=max_points);pred<-apply(grid[,object$factors,drop=FALSE],1,function(x).rf_predict_scalar(object,x));best<-optimum$predicted;keep<-if(goal=="max")pred>=best-tolerance*max(abs(best),.Machine$double.eps)else pred<=best+tolerance*max(abs(best),.Machine$double.eps);out<-grid[keep,object$factors,drop=FALSE];out$predicted<-pred[keep];attr(out,"tolerance")<-tolerance;attr(out,"optimum")<-best;out}

#' Unified uncertainty-aware optimization
#' @export
rsm_robust_optimize <- function(object,goal=c("max","min"),lambda=1.96,method=c("L-BFGS-B","GA"),seed=123){goal<-match.arg(goal);method<-match.arg(method);score<-function(x){pr<-.rf_predict_scalar(object,x,se.fit=TRUE);if(!is.finite(pr$se.fit))return(if(goal=="max")pr$fit else -pr$fit);if(goal=="max")pr$fit-lambda*pr$se.fit else -(pr$fit+lambda*pr$se.fit)};b<-object$bounds;if(method=="GA"){if(!requireNamespace("GA",quietly=TRUE)).rf_stop("Package 'GA' is required.");ga<-GA::ga(type="real-valued",fitness=score,lower=b$lower,upper=b$upper,popSize=80,maxiter=500,run=100,monitor=FALSE,seed=seed);x<-as.numeric(ga@solution[1,])}else{x<-stats::optim((b$lower+b$upper)/2,function(z)-score(z),method="L-BFGS-B",lower=b$lower,upper=b$upper)$par};pr<-.rf_predict_scalar(object,x,se.fit=TRUE);list(solution=setNames(x,object$factors),predicted=pr$fit,se=pr$se.fit,confidence_bound=if(goal=="max")pr$fit-lambda*pr$se.fit else pr$fit+lambda*pr$se.fit,goal=goal,lambda=lambda,method=method)}

#' Unified economic optimum
#' @export
rsm_economic_optimum <- function(object,response_price,factor_cost,fixed_cost=0,baseline=NULL,method=c("L-BFGS-B","GA"),seed=123){method<-match.arg(method);if(!.rf_model_supported(object)).rf_stop("object must be a supported rsmFlow model.");factors<-object$factors;if(is.null(names(factor_cost))||!all(factors%in%names(factor_cost))).rf_stop("factor_cost must be named for every fitted factor.");if(is.null(baseline))baseline<-setNames(object$bounds$lower,factors);if(is.null(names(baseline)))names(baseline)<-factors;revenue<-function(y)if(is.function(response_price))response_price(y)else as.numeric(response_price)*y;cost<-function(x)sum(vapply(seq_along(factors),function(j){cst<-factor_cost[[factors[j]]];amount<-x[j]-baseline[[factors[j]]];if(is.function(cst))cst(amount)else as.numeric(cst)*amount},numeric(1)))+fixed_cost;profit<-function(x){y<-.rf_predict_scalar(object,x);revenue(y)-cost(x)};b<-object$bounds;set.seed(seed);if(method=="GA"){if(!requireNamespace("GA",quietly=TRUE)).rf_stop("Package 'GA' is required.");ga<-GA::ga(type="real-valued",fitness=profit,lower=b$lower,upper=b$upper,popSize=100,maxiter=700,run=150,monitor=FALSE,seed=seed);x<-as.numeric(ga@solution[1,])}else{g<-.rf_design_grid(b,n=12,max_points=5000);st<-as.numeric(g[which.max(apply(g,1,profit)),factors,drop=TRUE]);x<-stats::optim(st,function(z)-profit(z),method="L-BFGS-B",lower=b$lower,upper=b$upper)$par};y<-.rf_predict_scalar(object,x);bio<-rsm_optimize(object,"max","L-BFGS-B");list(solution=setNames(x,factors),predicted_response=y,revenue=revenue(y),variable_plus_fixed_cost=cost(x),profit=profit(x),method=method,biological_optimum=bio$solution,biological_predicted=bio$predicted,model_kind=.rf_model_kind(object),interpretation="Economic optimum maximizes fitted revenue minus declared costs inside the experimental region.")}

#' Unified response-surface plotting
#' @export
rsm_plot <- function(object,type=c("contour","heatmap","surface","prediction_variance","residuals","qq","leverage","cooks","term_correlation","design","fds","vdg","canonical","profile","perturbation"),x=NULL,y=NULL,at=NULL,n=60,interactive=FALSE,show_points=TRUE,optimum=NULL,scale=c("response","link")){
  type<-match.arg(type);scale<-match.arg(scale);if(inherits(object,"rsmFlow_fit"))return(.rf_plot_lm(object,type=type,x=x,y=y,at=at,n=n,interactive=interactive,show_points=show_points,optimum=optimum));if(!.rf_model_supported(object)).rf_stop("Unsupported model object.");if(type%in%c("prediction_variance","leverage","cooks","term_correlation","design","fds","vdg","canonical")){if(type=="canonical"&&inherits(object,"rsmFlow_glm")){ca<-rsm_canonical(object);op<-structure(list(solution=ca$stationary_point,predicted=ca$predicted_response,method="canonical stationary point"),class="rsmFlow_optimum");return(rsm_plot(object,type="contour",x=x,y=y,at=at,n=n,interactive=interactive,show_points=show_points,optimum=op,scale=scale))}else .rf_stop("This plot type is currently specific to polynomial design-aware fits, except GLM canonical geometry.")};if(type=="profile"){if(is.null(x))x<-object$factors[1];return(plot(rsm_profile(object,x,at=at)))};if(type=="perturbation")return(plot(rsm_perturbation(object)));if(type%in%c("residuals","qq")){d<-data.frame(fitted=.rf_fitted_values(object),residual=.rf_residual_values(object));if(!requireNamespace("ggplot2",quietly=TRUE))return(d);if(type=="qq")return(ggplot2::ggplot(d,ggplot2::aes(sample=residual))+ggplot2::stat_qq()+ggplot2::stat_qq_line()+ggplot2::theme_minimal());return(ggplot2::ggplot(d,ggplot2::aes(x=fitted,y=residual))+ggplot2::geom_point()+ggplot2::geom_hline(yintercept=0,linetype=2)+ggplot2::theme_minimal())};if(is.null(x))x<-object$factors[1];if(is.null(y))y<-object$factors[2];xs<-seq(object$bounds$lower[[x]],object$bounds$upper[[x]],length.out=n);ys<-seq(object$bounds$lower[[y]],object$bounds$upper[[y]],length.out=n);g<-expand.grid(xs,ys,KEEP.OUT.ATTRS=FALSE);names(g)<-c(x,y);other<-setdiff(object$factors,c(x,y));if(is.null(at))at<-setNames(as.list((object$bounds$lower[other]+object$bounds$upper[other])/2),other);for(z in other)g[[z]]<-at[[z]] %||% mean(c(object$bounds$lower[[z]],object$bounds$upper[[z]]));g<-g[,object$factors,drop=FALSE];g$value<-.rf_predict_mean(object,g,scale=scale);if(type=="surface"&&interactive&&requireNamespace("plotly",quietly=TRUE)){z<-matrix(g$value,nrow=n,ncol=n);return(plotly::plot_ly(x=xs,y=ys,z=t(z),type="surface"))};if(type=="surface"&&!interactive){z<-matrix(g$value,nrow=n,ncol=n);graphics::persp(xs,ys,z,xlab=x,ylab=y,zlab=object$response,ticktype="detailed",theta=35,phi=25);return(invisible(list(x=xs,y=ys,z=z,grid=g)))};if(!requireNamespace("ggplot2",quietly=TRUE))return(g);p<-ggplot2::ggplot(g,ggplot2::aes_string(x=x,y=y));if(type=="contour")p<-p+ggplot2::geom_contour(ggplot2::aes(z=value))else p<-p+ggplot2::geom_raster(ggplot2::aes(fill=value),interpolate=TRUE)+ggplot2::geom_contour(ggplot2::aes(z=value));if(show_points)p<-p+ggplot2::geom_point(data=object$data,ggplot2::aes_string(x=x,y=y),inherit.aes=FALSE);if(!is.null(optimum)){op<-as.data.frame(as.list(optimum$solution));p<-p+ggplot2::geom_point(data=op,ggplot2::aes_string(x=x,y=y),inherit.aes=FALSE,shape=4,size=4)};p+ggplot2::theme_minimal()+ggplot2::labs(fill=object$response,title=paste(.rf_model_kind(object),"response surface"))}

#' Unified cross-validation for fitted rsmFlow models
#' @export
rsm_cv <- function(object, folds=5, repeats=1, group=NULL, seed=123){
  if(!.rf_model_supported(object)||inherits(object,"rsmFlow_surrogate")) .rf_stop("Cross-validation refitting currently supports Gaussian, GLM, and nonlinear fitted models.")
  dat<-object$data;n<-nrow(dat);if(folds<2).rf_stop("folds must be at least 2.");set.seed(seed)
  group_vec<-NULL;if(!is.null(group)){if(length(group)==1L&&is.character(group)&&group%in%names(dat))group_vec<-dat[[group]]else if(length(group)==n)group_vec<-group else .rf_stop("group must be a column name or vector.")}else .rf_warn("Ungrouped random cross-validation is supplementary in designed experiments; use group= when design units must remain intact.")
  rows<-list();ii<-1L
  for(r in seq_len(repeats)){
    if(is.null(group_vec))fid<-sample(rep(seq_len(folds),length.out=n)) else {ug<-unique(group_vec);gf<-sample(rep(seq_len(min(folds,length(ug))),length.out=length(ug)));fid<-gf[match(group_vec,ug)]}
    for(f in sort(unique(fid))){tr<-droplevels(dat[fid!=f,,drop=FALSE]);te<-droplevels(dat[fid==f,,drop=FALSE]);ff<-try(.rf_refit_model(object,tr,seed=seed+r*1000+f),silent=TRUE);if(inherits(ff,"try-error"))next;te_pred<-te;if(!is.null(object$block)&&object$block%in%names(te_pred))te_pred[[object$block]]<-NULL;pr<-try(.rf_predict_mean(ff,te_pred),silent=TRUE);if(inherits(pr,"try-error"))next;rows[[ii]]<-data.frame(repeat_id=r,fold=f,observed=te[[object$response]],predicted=as.numeric(pr));ii<-ii+1L}
  }
  pred<-if(length(rows))do.call(rbind,rows)else NULL;if(is.null(pred)||!nrow(pred)).rf_stop("No cross-validation fold could be fitted successfully.");e<-pred$observed-pred$predicted;den<-sum((pred$observed-mean(pred$observed))^2);metrics<-c(RMSE=sqrt(mean(e^2)),MAE=mean(abs(e)),R2=if(den>0)1-sum(e^2)/den else NA_real_);list(metrics=metrics,predictions=pred,grouped=!is.null(group_vec),group=group,model_kind=.rf_model_kind(object))
}

#' Stability of bootstrap optimum coordinates for any fitted rsmFlow model
#' @export
rsm_optimum_stability <- function(uncertainty,fit,tolerance=.10){if(is.null(uncertainty$bootstrap)).rf_stop("uncertainty must come from rsm_optimum_ci().");if(!.rf_model_supported(fit)).rf_stop("fit must be a supported rsmFlow model.");B<-uncertainty$bootstrap;factors<-fit$factors;est<-uncertainty$estimate[factors];ranges<-pmax(fit$bounds$upper-fit$bounds$lower,.Machine$double.eps);D<-sweep(as.matrix(B[,factors,drop=FALSE]),2,as.numeric(est),"-");D<-sweep(D,2,ranges,"/");dist<-sqrt(rowSums(D^2));ref<-.rf_predict_scalar(fit,as.numeric(est));pred<-apply(B[,factors,drop=FALSE],1,function(z).rf_predict_scalar(fit,z));loss<-abs(ref-pred)/max(abs(ref),.Machine$double.eps);list(tolerance=tolerance,probability_within_standardized_radius=mean(dist<=tolerance),standardized_distance_quantiles=stats::quantile(dist,c(.5,.8,.9,.95)),response_loss_quantiles=stats::quantile(loss,c(.5,.8,.9,.95)),model_kind=.rf_model_kind(fit),interpretation="Stability uses factor-range standardized distance and relative fitted-response loss.")}
