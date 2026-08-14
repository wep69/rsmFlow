# rsmFlow 0.2.0 frozen simulation battery
# Seed and scenario definitions frozen on 2026-08-13.
# This script MUST be executed in R before any quantitative performance claim is made.

library(rsmFlow)
set.seed(20260813)
dir.create("validation", showWarnings = FALSE)

safe_row <- function(expr, fallback = NULL) tryCatch(expr, error = function(e) fallback)

# -------------------------------------------------------------------------
# A. Surface geometry x non-orthogonality x noise
# -------------------------------------------------------------------------
sim_surface <- function(n = 70, rho = 0, type = c("maximum","minimum","saddle","ridge"), sigma=.2) {
  type <- match.arg(type)
  z1 <- rnorm(n); z2 <- rho*z1 + sqrt(max(1-rho^2,0))*rnorm(n)
  x1 <- pmax(pmin(z1/2,1),-1); x2 <- pmax(pmin(z2/2,1),-1)
  quad <- switch(type,
    maximum = -1.4*x1^2 - .8*x2^2,
    minimum =  1.4*x1^2 + .8*x2^2,
    saddle  =  1.1*x1^2 - .9*x2^2,
    ridge   = -1.2*x1^2 - .005*x2^2)
  y <- 8 + .5*x1 - .2*x2 + .25*x1*x2 + quad + rnorm(n,0,sigma)
  data.frame(x1,x2,y)
}
scA <- expand.grid(geometry=c("maximum","minimum","saddle","ridge"),rho=c(0,.5,.85,.97),sigma=c(.1,.3),rep=1:100,stringsAsFactors=FALSE)
resA <- lapply(seq_len(nrow(scA)), function(i) {
  s <- scA[i,]; d <- sim_surface(rho=s$rho,type=s$geometry,sigma=s$sigma)
  fit <- safe_row(rsm_fit(d,"y",c("x1","x2"),2)); if(is.null(fit)) return(NULL)
  au <- safe_row(rsm_design_audit(fit,rotatability=FALSE)); ca <- safe_row(rsm_canonical(fit))
  goal <- if(s$geometry=="minimum") "min" else "max"; op <- safe_row(rsm_optimize(fit,goal=goal,method="L-BFGS-B"))
  data.frame(geometry=s$geometry,rho=s$rho,sigma=s$sigma,rep=s$rep,
             estimable=if(is.null(au)) NA else au$estimable,
             condition=if(is.null(au)) NA else au$condition_number_scaled,
             classified=if(is.null(ca)) NA else ca$nature,
             optimum_ok=!is.null(op),stringsAsFactors=FALSE)
})
write.csv(do.call(rbind,resA),"validation/sim_A_geometry_nonorthogonality.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# B. Interior versus boundary/external stationary point
# -------------------------------------------------------------------------
scB <- expand.grid(case=c("interior","boundary","external"),rep=1:200,stringsAsFactors=FALSE)
resB <- lapply(seq_len(nrow(scB)),function(i){
  s<-scB[i,]; g<-expand.grid(x1=seq(-1,1,length.out=7),x2=seq(-1,1,length.out=7))
  center<-switch(s$case,interior=c(.25,-.20),boundary=c(1,.3),external=c(1.5,.3))
  g$y<-12-1.4*(g$x1-center[1])^2-.9*(g$x2-center[2])^2+rnorm(nrow(g),0,.15)
  fit<-rsm_fit(g,"y",c("x1","x2"),2); ca<-rsm_canonical(fit); op<-rsm_optimize(fit,"max","L-BFGS-B")
  data.frame(case=s$case,rep=s$rep,stationary_inside=ca$inside_region,
             x1=op$solution[1],x2=op$solution[2],on_boundary=any(abs(op$solution-c(-1,-1))<1e-5|abs(op$solution-c(1,1))<1e-5))
})
write.csv(do.call(rbind,resB),"validation/sim_B_boundary_behavior.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# C. Bootstrap coverage of known optimum
# -------------------------------------------------------------------------
scC <- expand.grid(sigma=c(.10,.25,.50),rep=1:100,stringsAsFactors=FALSE)
true_opt <- c(x1=.30,x2=-.20)
resC <- lapply(seq_len(nrow(scC)),function(i){
  s<-scC[i,]; g<-expand.grid(x1=seq(-1,1,length.out=6),x2=seq(-1,1,length.out=6))
  g$y<-10-1.2*(g$x1-true_opt[1])^2-.8*(g$x2-true_opt[2])^2+rnorm(nrow(g),0,s$sigma)
  fit<-rsm_fit(g,"y",c("x1","x2"),2); op<-rsm_optimize(fit,"max","L-BFGS-B")
  u<-safe_row(rsm_optimum_ci(fit,op,B=199,method="parametric",seed=20260813+i)); if(is.null(u)) return(NULL)
  data.frame(sigma=s$sigma,rep=s$rep,B_valid=u$B_valid,
             cover_x1=true_opt[1]>=u$intervals["x1","lower"]&&true_opt[1]<=u$intervals["x1","upper"],
             cover_x2=true_opt[2]>=u$intervals["x2","lower"]&&true_opt[2]<=u$intervals["x2","upper"])
})
write.csv(do.call(rbind,resC),"validation/sim_C_optimum_coverage.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# D. Heteroscedasticity: OLS versus feasible power-variance WLS
# -------------------------------------------------------------------------
scD <- expand.grid(hetero=c(0,.5,1),rep=1:200)
resD <- lapply(seq_len(nrow(scD)),function(i){
  s<-scD[i,]; g<-expand.grid(x1=seq(-1,1,length.out=8),x2=seq(-1,1,length.out=8)); mu<-8+.5*g$x1-.3*g$x2-1.1*g$x1^2-.7*g$x2^2
  sdv<-.15*exp(s$hetero*(mu-mean(mu))/sd(mu)); g$y<-mu+rnorm(nrow(g),0,sdv)
  fo<-rsm_fit(g,"y",c("x1","x2"),2,estimator="ols")
  fw<-safe_row(rsm_fit(g,"y",c("x1","x2"),2,estimator="wls_power"))
  data.frame(hetero=s$hetero,rep=s$rep,rmse_ols=sqrt(mean(residuals(fo$model)^2)),rmse_wls=if(is.null(fw)) NA else sqrt(mean(residuals(fw$model)^2)))
})
write.csv(do.call(rbind,resD),"validation/sim_D_heteroscedasticity.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# E. Blocking and lack-of-fit reference
# -------------------------------------------------------------------------
scE <- expand.grid(curvature_misspec=c(FALSE,TRUE),rep=1:200)
resE <- lapply(seq_len(nrow(scE)),function(i){
  s<-scE[i,]; d<-expand.grid(Block=factor(1:4),x1=c(-1,0,1),x2=c(-1,0,1)); be<-c(-.8,-.2,.3,.7)
  d$y<-10+1.2*d$x1-.7*d$x2-.8*d$x1^2-.5*d$x2^2+be[as.integer(d$Block)]+rnorm(nrow(d),0,.15)
  if(s$curvature_misspec) fit<-rsm_fit(d,"y",c("x1","x2"),1,block="Block") else fit<-rsm_fit(d,"y",c("x1","x2"),2,block="Block")
  lf<-rsm_lack_of_fit(fit); data.frame(misspecified=s$curvature_misspec,rep=s$rep,available=lf$available,p=if(lf$available) lf$lack_of_fit[["p.value"]] else NA)
})
write.csv(do.call(rbind,resE),"validation/sim_E_block_lack_of_fit.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# F. Dimensionality: 2 to 6 quantitative factors
# -------------------------------------------------------------------------
scF <- expand.grid(k=2:6,rep=1:100)
resF <- lapply(seq_len(nrow(scF)),function(i){
  s<-scF[i,]; k<-s$k; p<-1+2*k+k*(k-1)/2; n<-max(4*p,80)
  X<-matrix(runif(n*k,-1,1),ncol=k); colnames(X)<-paste0("x",1:k); d<-as.data.frame(X)
  lin<-seq(.4,.1,length.out=k); mu<-8+as.numeric(X%*%lin)-rowSums(sweep(X^2,2,seq(.8,.3,length.out=k),"*")); d$y<-mu+rnorm(n,0,.2)
  fit<-safe_row(rsm_fit(d,"y",colnames(X),2)); au<-if(is.null(fit)) NULL else safe_row(rsm_design_audit(fit,grid_n=8,rotatability=FALSE)); op<-if(is.null(fit)) NULL else safe_row(rsm_optimize(fit,"max","L-BFGS-B"))
  data.frame(k=k,rep=s$rep,fit_ok=!is.null(fit),estimable=if(is.null(au)) NA else au$estimable,condition=if(is.null(au)) NA else au$condition_number_scaled,optimum_ok=!is.null(op))
})
write.csv(do.call(rbind,resF),"validation/sim_F_dimension_2_to_6.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# G. Design augmentation on an intentionally correlated design
# -------------------------------------------------------------------------
scG <- 1:100
resG <- lapply(scG,function(r){
  x1<-runif(28,-1,1); x2<-pmin(pmax(.85*x1+rnorm(28,0,.18),-1),1); d<-data.frame(x1,x2); d$y<-10+x1-.5*x2-x1^2-.8*x2^2+rnorm(28,0,.2)
  fit<-safe_row(rsm_fit(d,"y",c("x1","x2"),2)); if(is.null(fit)) return(NULL)
  before<-safe_row(rsm_design_audit(fit,grid_n=15,rotatability=FALSE)); aug<-rsm_augment(fit,n_add=5,objective="I",grid_n=9)
  d2<-rbind(d,data.frame(aug,y=10+aug$x1-.5*aug$x2-aug$x1^2-.8*aug$x2^2+rnorm(nrow(aug),0,.2)))
  f2<-rsm_fit(d2,"y",c("x1","x2"),2); after<-rsm_design_audit(f2,grid_n=15,rotatability=FALSE)
  data.frame(rep=r,before_max_spv=before$prediction_variance[["max"]],after_max_spv=after$prediction_variance[["max"]],before_mean_spv=before$prediction_variance[["mean"]],after_mean_spv=after$prediction_variance[["mean"]])
})
write.csv(do.call(rbind,resG),"validation/sim_G_design_augmentation.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# H. Conflicting multiresponse optimization and Pareto set
# -------------------------------------------------------------------------
g<-expand.grid(x1=seq(-1,1,length.out=9),x2=seq(-1,1,length.out=9)); g$y1<-10-(g$x1-.5)^2-(g$x2-.2)^2+rnorm(nrow(g),0,.05); g$y2<-8-(g$x1+.5)^2-(g$x2+.3)^2+rnorm(nrow(g),0,.05)
f1<-rsm_fit(g,"y1",c("x1","x2"),2); f2<-rsm_fit(g,"y2",c("x1","x2"),2)
pareto<-rsm_pareto(list(f1,f2),c("max","max"),n=5000,engine="sample")
des<-rsm_multiopt(list(f1,f2),c("max","max"),list(list(low=min(g$y1),high=max(g$y1)),list(low=min(g$y2),high=max(g$y2))),method="desirability",optimizer="L-BFGS-B")
write.csv(pareto,"validation/sim_H_pareto.csv",row.names=FALSE); write.csv(data.frame(t(des$solution),objective=des$objective),"validation/sim_H_desirability_solution.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# I. Biological versus economic optimum
# -------------------------------------------------------------------------
g<-expand.grid(N=seq(0,200,length.out=9),K=seq(0,120,length.out=9)); g$Yield<-4+.04*g$N+.03*g$K-.00015*g$N^2-.00020*g$K^2+rnorm(nrow(g),0,.03)
fit<-rsm_fit(g,"Yield",c("N","K"),2); bio<-rsm_optimize(fit,"max","L-BFGS-B"); eco<-rsm_economic_optimum(fit,response_price=1200,factor_cost=c(N=5.5,K=4.0))
write.csv(data.frame(type=c("biological","economic"),N=c(bio$solution["N"],eco$solution["N"]),K=c(bio$solution["K"],eco$solution["K"]),predicted=c(bio$predicted,eco$predicted_response),profit=c(NA,eco$profit)),"validation/sim_I_economic_optimum.csv",row.names=FALSE)

cat("Core frozen scenarios A-I completed. Continuing with GLM/nonlinear/Tier-3 extensions.\n")

# -------------------------------------------------------------------------
# J. GLM-RSM family recovery and bounded optimum behavior
# -------------------------------------------------------------------------
set.seed(20260814)
scJ <- expand.grid(family=c("poisson","binomial","gamma"),rep=1:100,stringsAsFactors=FALSE)
resJ <- lapply(seq_len(nrow(scJ)),function(i){
  s<-scJ[i,]; g<-expand.grid(x1=seq(-1,1,length.out=7),x2=seq(-1,1,length.out=7))
  eta<-1.5+.25*g$x1-.15*g$x2-.35*g$x1^2-.20*g$x2^2+.08*g$x1*g$x2
  if(s$family=="poisson"){g$y<-rpois(nrow(g),exp(eta));fam<-poisson()}
  else if(s$family=="binomial"){g$n<-30;g$y<-rbinom(nrow(g),g$n,plogis(eta))/g$n;fam<-binomial()}
  else {mu<-exp(eta);g$y<-rgamma(nrow(g),shape=8,scale=mu/8);fam<-Gamma(link="log")}
  fit<-safe_row(rsm_glm_fit(g,"y",c("x1","x2"),family=fam,weights=if(s$family=="binomial")g$n else NULL));if(is.null(fit))return(NULL)
  op<-safe_row(rsm_optimize(fit,"max","L-BFGS-B"));dg<-safe_row(rsm_glm_dispersion(fit))
  data.frame(family=s$family,rep=s$rep,fit_ok=TRUE,optimum_ok=!is.null(op),dispersion=if(is.null(dg))NA else dg$pearson_dispersion)
})
write.csv(do.call(rbind,resJ),"validation/sim_J_glm_rsm.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# K. Nonlinear parameter recovery and convergence
# -------------------------------------------------------------------------
set.seed(20260815)
scK <- expand.grid(model=c("mitscherlich2_product","michaelis_menten2"),sigma=c(.03,.12),rep=1:100,stringsAsFactors=FALSE)
resK <- lapply(seq_len(nrow(scK)),function(i){
  s<-scK[i,];d<-expand.grid(N=seq(10,160,length.out=7),P=seq(5,90,length.out=7))
  if(s$model=="mitscherlich2_product"){
    truth<-c(A=11,k1=.025,k2=.04);d$y<-truth[1]*(1-exp(-truth[2]*d$N))*(1-exp(-truth[3]*d$P))+rnorm(nrow(d),0,s$sigma)
    st<-c(A=10,k1=.02,k2=.03)
  } else {
    truth<-c(A=12,K1=30,K2=20);d$y<-truth[1]*d$N/(truth[2]+d$N)*d$P/(truth[3]+d$P)+rnorm(nrow(d),0,s$sigma)
    st<-c(A=11,K1=25,K2=18)
  }
  fit<-safe_row(rsm_nonlinear_fit(d,"y",c("N","P"),s$model,start=st,engine="nls"));if(is.null(fit))return(data.frame(model=s$model,sigma=s$sigma,rep=s$rep,converged=FALSE))
  dg<-rsm_nonlinear_diagnostics(fit);cf<-coef(fit$model)
  data.frame(model=s$model,sigma=s$sigma,rep=s$rep,converged=dg$converged,RMSE=dg$RMSE,jacobian_condition=dg$jacobian_condition,
             max_relative_parameter_error=max(abs((cf[names(truth)]-truth)/truth),na.rm=TRUE))
})
write.csv(do.call(rbind,resK),"validation/sim_K_nonlinear_recovery.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# L. GA versus random multistart for nonlinear initial values
# -------------------------------------------------------------------------
if(requireNamespace("GA",quietly=TRUE)){
  set.seed(20260816);d<-expand.grid(N=seq(10,160,length.out=7),P=seq(5,90,length.out=7));d$y<-11*(1-exp(-.025*d$N))*(1-exp(-.04*d$P))+rnorm(nrow(d),0,.08)
  base_fit <- rsm_nonlinear_fit(d,"y",c("N","P"),"mitscherlich2_product",
                                  start=c(A=11,k1=.025,k2=.04),engine="nls")
  bb <- base_fit$parameter_bounds
  form <- base_fit$formula
  ga_rows<-lapply(1:50,function(r){a<-rsm_nonlinear_start_ga(d,form,bb,seed=10000+r,ga_control=list(popSize=30,maxiter=60,run=20));m<-rsm_nonlinear_start_multistart(d,form,bb,n_start=500,seed=20000+r);data.frame(rep=r,GA_SSE=a$SSE,multistart_SSE=m$SSE)})
  write.csv(do.call(rbind,ga_rows),"validation/sim_L_start_search.csv",row.names=FALSE)
}

# -------------------------------------------------------------------------
# M. Tier-3 surrogate smoke/benchmark scenarios (conditional dependencies)
# -------------------------------------------------------------------------
set.seed(20260817);d<-data.frame(x1=runif(100,-1,1),x2=runif(100,-1,1));d$y<-sin(2.4*d$x1)+.7*cos(2*d$x2)+.25*d$x1*d$x2+rnorm(100,0,.05)
resM<-list()
if(requireNamespace("mgcv",quietly=TRUE)){
  g<-safe_row(rsm_surrogate(d,"y",c("x1","x2"),"gam"));if(!is.null(g))resM[["gam"]]<-data.frame(engine="gam",RMSE=sqrt(mean((d$y-predict(g,d[,c("x1","x2")]))^2)))
  tps<-safe_row(rsm_surrogate(d,"y",c("x1","x2"),"tps"));if(!is.null(tps))resM[["tps"]]<-data.frame(engine="tps",RMSE=sqrt(mean((d$y-predict(tps,d[,c("x1","x2")]))^2)))
}
if(requireNamespace("DiceKriging",quietly=TRUE)){g<-safe_row(rsm_surrogate(d,"y",c("x1","x2"),"gp"));if(!is.null(g))resM[["gp"]]<-data.frame(engine="gp",RMSE=sqrt(mean((d$y-predict(g,d[,c("x1","x2")]))^2)))}
if(requireNamespace("ranger",quietly=TRUE)){g<-safe_row(rsm_surrogate(d,"y",c("x1","x2"),"rf"));if(!is.null(g))resM[["rf"]]<-data.frame(engine="rf",RMSE=sqrt(mean((d$y-predict(g,d[,c("x1","x2")]))^2)))}
if(requireNamespace("nnet",quietly=TRUE)){g<-safe_row(rsm_surrogate(d,"y",c("x1","x2"),"nn"));if(!is.null(g))resM[["nn"]]<-data.frame(engine="nn",RMSE=sqrt(mean((d$y-predict(g,d[,c("x1","x2")]))^2)))}
if(length(resM))write.csv(do.call(rbind,resM),"validation/sim_M_tier3_surrogates.csv",row.names=FALSE)

# -------------------------------------------------------------------------
# N. Tier-3 GNLS under response-dependent heteroscedasticity
# -------------------------------------------------------------------------
if(requireNamespace("nlme",quietly=TRUE)){
  set.seed(20260818)
  scN<-expand.grid(hetero=c(.0,.5,1.0),rep=1:50)
  resN<-lapply(seq_len(nrow(scN)),function(i){
    z<-scN[i,];dd<-expand.grid(N=seq(10,160,length.out=7),P=seq(5,90,length.out=7))
    mu<-12*dd$N/(30+dd$N)*dd$P/(20+dd$P)
    sdv<-.04*exp(z$hetero*(mu-mean(mu))/sd(mu));dd$y<-mu+rnorm(nrow(dd),0,sdv)
    fn<-safe_row(rsm_nonlinear_fit(dd,"y",c("N","P"),model="michaelis_menten2",
      start=c(A=11,K1=25,K2=18),engine="nls"))
    fg<-safe_row(rsm_nonlinear_fit(dd,"y",c("N","P"),model="michaelis_menten2",
      start=c(A=11,K1=25,K2=18),engine="gnls",variance="power"))
    data.frame(hetero=z$hetero,rep=z$rep,nls_ok=!is.null(fn),gnls_ok=!is.null(fg),
      RMSE_nls=if(is.null(fn))NA else rsm_nonlinear_diagnostics(fn)$RMSE,
      RMSE_gnls=if(is.null(fg))NA else rsm_nonlinear_diagnostics(fg)$RMSE)
  })
  write.csv(do.call(rbind,resN),"validation/sim_N_gnls_heteroscedasticity.csv",row.names=FALSE)
}

cat("Frozen rsmFlow 0.2.0 simulation battery completed where optional dependencies were available. Inspect all failures and summaries before scientific performance claims.\n")
