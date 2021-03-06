#'Imputation Parameter Estimation for Linear Regression
#'
#'Given the data, this function estimates the imputation parameters.
#'This function is a wrapper for \code{fcr} if \code{cond.y} is set to TRUE,
#'and \code{face.sparse} if \code{cond.y} is set to FALSE.
#'
#'@param dat A data frame with \eqn{n} rows (where \eqn{N} is the number of subjects,
#'       each with \eqn{m_i} observations, so that \eqn{\sum_{i=1}^N m_i = n})
#'       expected to have either 3 or 4. If \code{cond.y} is TRUE, should include
#'       4 columns, with variables 'X','y','subj', and 'argvals'. If \code{cond.y}
#'       is FALSE, only 3 columns are needed (no 'y' variable is used).
#'@param workGrid A length \eqn{M} vector of the unique desired grid points on which to evaluate the function.
#'@param cond.y A logical indicator to determine whether imputation will be done conditional on \eqn{Y}.
#'@param fcr.args A list of arguments to be passed to the underlying function \code{fcr}.
#'@param k Dimension of the smooth terms used in \code{fcr}. Only needs to be specified if \code{cond.y} is TRUE.
#'@param nPhi An integer value, indicating the number of random effects to include in the model. This is
#'passed to \code{fcr} and is only used when \code{cond.y} is TRUE. See \code{fcr} for more details.
#'@param face.args A list of arguments to be passed to the underlying function \code{face.sparse}.
#'@details
#'@return
#'@author
#'@references
#'@example
#'@export


param_est_linear <- function(dat,y,workGrid,M,cond.y=TRUE,use_fcr = TRUE,
                             fcr.args = list(use_bam = T,niter = 1),
                             k = -1,#nPhi = NULL,
                             face.args=list(knots = 12, lower = -3, pve = 0.95),
                             FPCA.args = NULL){
  N <- length(unique(dat[,"subj"]))
  start_time <- proc.time()
  if(cond.y){
    # muy <- (dat %>% group_by(subj) %>% summarise(y = first(y)) %>% summarise(mean(y)))[[1]]
    # var_y <- (dat %>% group_by(subj) %>% summarise(y = first(y)) %>% summarise(var(y)))[[1]]
    muy <- mean(y)
    var_y <- var(y)

    # if(is.null(nPhi)){
    #   if(k== - 1){
    #     nPhi <- floor((nrow(dat) - 2*10)/N)
    #   }else{
    #     nPhi <- floor((nrow(dat) - 2*k)/N) # this is based on using the same basis for both smooths
    #   }
    # }

    if(use_fcr){
      params <- param_est_fcr(dat,workGrid,muy,var_y,fcr.args,k,face.args)#,nPhi)
    }else{
      params <- param_est_pace(dat,M,cond.y,muy,FPCA.args)
    }
    # ks <- deparse(substitute(k))
    # if(!is.null(nPhi)){fcr.args['nPhi'] <- nPhi}
    # rhs <- paste("s(argvals, k =", ks,", bs = \"ps\") + s(argvals, by = y, k =", ks,", bs = \"ps\")")
    # model <- reformulate(response = "X",termlabels = rhs)
    # rhs <- paste("~ ", "s(argvals, k =", k,", bs = \"ps\") + s(argvals, by = y, k =", k,", bs = \"ps\")")
    # model <- update.formula(rhs, "X ~ .")
    # cat("model looks like: ", paste(model))
    # fit <- do.call("fcr",c(list(formula = model, data = dat, subj = "subj",
    #                           argvals = "argvals", face.args = face.args,
    #                           argvals.new = workGrid,nPhi = nPhi),
    #                fcr.args))
    # Cb <- fit$face.object$Chat.new
    # ci <- match(workGrid,fit$face.object$argvals.new)
    # Cb <- Cb[ci,ci]
    # var_delt <- fit$face.object$var.error.hat[1]
    #
    # predcoefs <- predict(fit,newdata = data.frame("argvals" = workGrid,"y" = 1,"subj"=1),type='iterms',se.fit=TRUE)
    # predcoefs <- predcoefs$insample_predictions
    # predcoefs$fit[,1] <- predcoefs$fit[,1] + attributes(predcoefs)$constant ## add back in \hat{\beta_0}
    # f1 <- predcoefs$fit[,1]
    # f2 <- predcoefs$fit[,2]
    # mux <- f1 + muy*f2
    # Cx <- var_y*f2%*%t(f2) + Cb
    # Cxeig <- eigen(Cx)
    # Cxy <- var_y*f2
    # lam <- Cxeig$values/length(workGrid)
    # phi <- Cxeig$vectors*sqrt(length(workGrid))
    # params <- list(mux = mux,Cx = Cx,lam = lam,phi = phi,var_delt = var_delt,
    #                muy = muy,var_y = var_y,Cxy = Cxy)
    params[["muy"]] <- muy
    params[["var_y"]] <- var_y
    # pve = fit$face.object$pve
  }else{
    ## Parameters for distribution of Xi_i|{x_ij}:
    if(use_fcr){
      facedf <- dat[,c("X","argvals","subj")]
      colnames(facedf) <- c("y","argvals","subj")
      fit <- do.call("face.sparse",c(list(data = facedf,argvals.new = workGrid),face.args))
      mux <- fit$mu.new
      Cx <- fit$Chat.new
      Cxeig <- eigen(Cx)
      lam <- Cxeig$values/length(workGrid)
      phi <- Cxeig$vectors*sqrt(length(workGrid))
      var_delt <- fit$var.error.new[1]
      params <- list(mux = mux,Cx = Cx,lam = lam,phi = phi,var_delt = var_delt)
      # pve = fit$pve
    }else{
      params <- param_est_pace(dat,M,cond.y,FPCA.args = FPCA.args)
    }
  }
  runtime <- proc.time() - start_time
  return(list(params = params,runtime = runtime))
}
