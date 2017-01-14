#' Changes in Volatility Identification
#'
#' Identify B matrix based on changes in Volatility.
#'
#' @param x VAR-object. (S)VAR model to determine B matrix for
#' @param SB integer. Structural break either of type integer as the number of observations which belong to the pre-break period or
#'                    Date character. If a date character is provided, either a date Vector which contains the time line of the data
#'                    in corresponding format or then the conventional time parameters need to be provided.
#' @param dateVector vector. Vector of the time period concerned containing SB
#' @param start character. Start of the time series (only if dateVector is empty)
#' @param end character. End of the time series (only if dateVector is empty)
#' @param frequency character. Frequency of the time series (only if dateVector is empty)
#' @param format character. Date format (only if dateVector is empty)
#' @param restriction_matrix matrix. A matrix containing presupposed Values and NA for values to be estimated
#' @return A list of class "svarIdent" with elements
#' \item{Lambda}{Estimated unconditional heteroscedasticity Matrix}
#' \item{Lambda_SE}{Matrix of standard errors of Lambda}
#' \item{B}{Estimated B matrix, i.e. unique decomposition of the covariance matrix}
#' \item{B_SE}{Standard Errors of B matrix}
#' \item{n}{Number of observations}
#' \item{Fish}{Observerd Fisher information matrix}
#' \item{Lik}{Function value of likelihood}
#' \item{wald_statistic}{Results of pairwise Wald tests}
#' \item{iteration}{Number of GLS estimations}
#' \item{method}{The applied identifaction method}
#' \item{SB}{Structural break as number of observation}
#' \item{SBcharacter}{Structural break as date (if provided in function arguments)}
#'
#'
#'
#' @examples
#' \dontrun{
#' require(vars)
#' # data contains quartlery observations from 1965Q1 to 2008Q3
#' # assumed structural break in 1979Q4
#' # x = output gap
#' # pi = inflation
#' # i = interest rates
#' set.seed(23211)
#' v1 <- VAR(USA, lag.max = 10, ic = "AIC" )
#' x1 <- id.cv(v1, SB = 60)
#' }
#'
#' @export


#--------------------------------------------#
## Identification via changes in volatility ##
#--------------------------------------------#

# x  : object of class VAR
# SB : Structural Break


id.cv <- function(x, SB, start = NULL, end = NULL, frequency = NULL,
                        format = NULL, dateVector = NULL, max.iter = 15, crit = 0.05, restriction_matrix = NULL){

  if(is.numeric(SB)){
    SBcharacter <- NULL
  }

  if(!is.numeric(SB)){
    SBcharacter <- SB
    SB <- getStructuralBreak(SB = SB, start = start, end = end,
                             frequency = frequency, format = format, dateVector = dateVector)
  }

  y_lag_cr <- function(y, lag_length){
    # create matrix that stores the lags
    y_lag <- matrix(NA, dim(y)[1],dim(y)[2]*lag_length)
    for (i in 1:lag_length) {
      y_lag[(1+i):dim(y)[1],((i*NCOL(y)-NCOL(y))+1):(i*NCOL(y))] <- y[1:(dim(y)[1]-i),(1:NCOL(y))]
    }
    # drop first observation
    y_lag <- as.matrix(y_lag[-(1:lag_length),])
    out <- list(lags = y_lag)
  }

  u_t <- residuals(x)
  p <- x$p
  Tob <- x$obs
  k <-x$K

  TB <- SB - p

  resid1 <- u_t[1:TB-1,]
  resid2 <- u_t[TB:Tob,]
  Sigma_hat1 <- (crossprod(resid1)) / (TB-1)
  Sigma_hat2 <- (crossprod(resid2)) / (Tob-TB+1)

   # Determine starting values for B and Lambda
   MLE <- NULL
   counter2 <- 0
   while(is.null(MLE) & counter2 < 5){
     MW <- -1
     while(MW < 0.5){
       B <- expm::sqrtm((1/Tob)* crossprod(u_t)) + matrix(runif(k*k), nrow = k, byrow = T)
       MW <- det(tcrossprod(B))
     }
     Lambda <- c(1,1,1)
     S <- c(cbind(B, Lambda))

     # optimize the likelihood function
     MLE <- tryCatch(
       optim(fn = LH, par = S, k = k, TB = TB, Sigma_hat1 = Sigma_hat1,
             Sigma_hat2 = Sigma_hat2, Tob = Tob, method = 'L-BFGS-B', hessian = T, restriction_matrix = restriction_matrix),
       error = function(e) NULL)
     counter2 <- counter2 + 1
     if(counter2 == 5){
       cat('Algorithm does not converge')
     }
   }

    B_hat <- matrix(MLE$par[1:(k*k)], nrow = k)
    Lambda_hat <- diag(MLE$par[(k*k+1):(k*k+k)])
    ll <- MLE$value

    # estimating again with GLS to obatin a more precise estimation
    y <- t(x$y)

    yl <- t(y_lag_cr(t(y), p)$lags)
    y <- y[,-c(1:p)]

    Z_t <- rbind(rep(1, ncol(yl)), yl)

    gls1 <- function(Z, Sig){
      G <- kronecker(tcrossprod(Z), Sig)
      return(G)
    }

    resid.gls <- function(Z_t, k, GLS_hat){
      term1 <- kronecker(t(Z_t), diag(k))%*%GLS_hat
      return(term1)
    }

    Lambda_hat <- list(Lambda_hat)
    B_hat <- list(B_hat)
    ll <- list(ll)

    counter <- 1
    Exit <- 1

    while(abs(Exit) > 0.05 & counter < 15){

      Sig1 <- solve(tcrossprod(B_hat[[counter]]))
      Sig2 <- solve(B_hat[[counter]]%*%tcrossprod(Lambda_hat[[counter]], B_hat[[counter]]))

      GLS1.1 <- rowSums(apply(Z_t[, 1:(TB-1)], 2, gls1, Sig = Sig1))
      GLS1.2 <- rowSums(apply(Z_t[, (TB):ncol(Z_t)], 2, gls1, Sig = Sig2))
      GLS1 <- solve(matrix(GLS1.1 + GLS1.2, nrow = k*k*p+k, byrow = F))

      GLS2.1 <- matrix(0, nrow = k*k*p+k, ncol = (TB-1))
      GLS2.2 <- matrix(0, nrow = k*k*p+k, ncol = ncol(y))


      for(i in 1:(TB-1)){
        GLS2.1[,i] <- kronecker(Z_t[,i], Sig1)%*%y[,i]
      }
      for(i in TB:ncol(Z_t)){
        GLS2.2[,i] <- kronecker(Z_t[,i], Sig2)%*%y[,i]
      }


      GLS2.1 <- rowSums(GLS2.1)
      GLS2.2 <- rowSums(GLS2.2)
      GLS2 <- GLS2.1 + GLS2.2

      GLS_hat <- GLS1%*%GLS2

      term1 <- apply(Z_t, 2, resid.gls, k = k, GLS_hat = GLS_hat)
      u_tgls <- t(y) - t(term1)

      resid1gls <- u_tgls[1:TB-1,]
      resid2gls <- u_tgls[TB:Tob,]
      Sigma_hat1gls <- (crossprod(resid1gls)) / (TB-1)
      Sigma_hat2gls <- (crossprod(resid2gls)) / (Tob-TB+1)

      # Determine starting values for B and Lambda
      MLEgls <- NULL
      counter2 <- 0
      while(is.null(MLEgls) & counter2 < 5){
        MW <- -1
        #MW2 <- -1
        while(MW < 0.5){
          B <- expm::sqrtm((1/Tob)* crossprod(u_tgls)) + matrix(runif(k*k), nrow = k, byrow = T)
          MW <- det(tcrossprod(B))
          #MW2 <- det(B %*% tcrossprod(Psi, B))
        }
        #Lambda <- diag(Lambda_hat[[counter]])
        S <- c(cbind(B, c(1,1,1)))

        #optimize the likelihood function
        MLEgls <- tryCatch(
          optim(fn = LH, par = S, k = k, TB = TB, Sigma_hat1 = Sigma_hat1gls,
                Sigma_hat2 = Sigma_hat2gls, Tob = Tob, method = 'L-BFGS-B', hessian = T, restriction_matrix = restriction_matrix),
          error = function(e) NULL)
        counter2 <- counter2 + 1
        if(counter2 == 5){
          cat('Algorithm does not converge')
        }
      }


      B_hatg <- matrix(MLEgls$par[1:(k*k)], nrow = k)
      Lambda_hatg <- diag(MLEgls$par[(k*k+1):(k*k+k)])
      ll_g <- MLEgls$value

      B_hat <- c(B_hat, list(B_hatg))
      Lambda_hat <- c(Lambda_hat, list(Lambda_hatg))
      ll <- c(ll, list(ll_g))

      counter <- counter +1
      #Exit <- sum(diag(Lambda_hat[[counter]])) - sum(diag(Lambda_hat[[counter - 1]]))
      Exit <- ll[[counter]] - ll[[counter-1]]
    }

    # extracting the best estimates
    ll <- unlist(ll)
    llf <- ll[which.min(ll)]
    cc <- which.min(ll)
    B_hat <- B_hat[[cc]]
    Lambda_hat <- Lambda_hat[[cc]]

    # obtaining standard errors from inverse fisher information matrix
    HESS <- solve(MLEgls$hessian)

    for(i in 1:nrow(HESS)){
      if(HESS[i,i] < 0){
        HESS[,i] <- -HESS[,i]
      }
    }

    FishObs <- sqrt(diag(HESS))
    B.SE <- matrix(FishObs[1:(k*k)], k, k)
    Lambda.SE <- FishObs[(k*k+1):(k*k+k)]*diag(k)


    # ordering the columns with respect to the largest absolute values in each column
    B_hat_ord <- matrix(0, k, k)
    control <- rep(0, k)
    for(i in 1:ncol(B_hat)){
      for(j in 1:ncol(B_hat)){
        if(which.max(abs(B_hat[, j])) == i){
          if(control[i] == 0){
            control[i] <- j
            B_hat_ord[, i] <-B_hat[, j]
          }else{
            if(max(B_hat[, j]) > max(B_hat[, control[i]])){
              control[i] <- j
              B_hat_ord[, i] <-B_hat[, j]
            }
          }
        }
      }
    }

    # checking if any column in the orderd matrix is empty and replace it with the unused column in the estimated matrix
    if(any(control == 0)){
      hc <- sapply(1:k, function(x){any(x == control)})
      B_hat_ord[, which(control == 0)] <- B_hat[, which(hc == FALSE)]
      control[which(control == 0)] <- which(hc == FALSE)
    }

    # checking for negative values on the main daigonal
    for(i in 1:ncol(B_hat_ord)){
      if(B_hat_ord[i,i] < 0){
        B_hat_ord[, i] <- B_hat_ord[, i]*(-1)
      }
      if(Lambda_hat[i,i] < 0){
        Lambda_hat[, i] <- Lambda_hat[, i]*(-1)
      }
    }

    # reordering the lambda and S.E. matrices in the same way
    B.SE <- B.SE[, control]
    Lambda_hat <- diag(diag(Lambda_hat[, control]))
    Lambda.SE <- diag(diag(Lambda.SE[, control]))

    # Testing the estimated SVAR for identification by menas of wald statistic
    wald <- wald.test(Lambda_hat, HESS)

  result <- list(
                 Lambda = Lambda_hat,    # estimated Lambda matrix (unconditional heteroscedasticity)
                 Lambda_SE = Lambda.SE,  # standard errors of Lambda matrix
                 B = B_hat_ord,          # estimated B matrix (unique decomposition of the covariance matrix)
                 B_SE = B.SE,            # standard errors of B matrix
                 n = Tob,                # number of observations
                 Fish = HESS,            # observerd fisher information matrix
                 Lik = -llf,    # function value of likelihood
                 wald_statistic = wald,  # results of wald test
                 iteration = counter,     # number of gls estimations
                 method = "Changes in Volatility",
                 SB = SB,                # Structural Break in number format
                 SBcharacter             # Structural Break in input character format
                 )
  class(result) <- "svarIdent"
  return(result)
}