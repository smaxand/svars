#' Forecast error variance decomposition for SVAR Models
#'
#' Calculation of forecast error variance decomposition for an identified SVAR object 'svars' derived by function id.cvm( ),id.cv( ),id.dc( ) or id.ngml( ).
#'
#' @param x SVAR object of class "svars"
#' @param horizon Time horizon for forecast error variance decomposition
#'
#' @seealso \code{\link{id.cvm}}, \code{\link{id.dc}}, \code{\link{id.ngml}} or \code{\link{id.cv}}
#'
#' @examples
#' \donttest{
#' v1 <- vars::VAR(USA, lag.max = 10, ic = "AIC" )
#' x1 <- id.dc(v1)
#' x2 <- fev(x1, horizon = 30)
#' plot(x2)
#' }
#'
#' @export

fev <- function(x, horizon = 10){

  # Function to calculate matrix potence
  "%^%" <- function(A, n){
    if(n == 1){
      A
    }else{
      A %*% (A %^% (n-1))
    }
  }

  # function to calculate impulse response
  IrF <- function(A_hat, B_hat, horizon){
    k <- nrow(A_hat)
    p <- ncol(A_hat)/k
    if(p == 1){
      irfa <- array(0, c(k, k, horizon))
      irfa[,,1] <- B_hat
      for(i in 1:horizon){
        irfa[,,i] <- (A_hat%^%i)%*%B_hat
      }
      return(irfa)
    }else{
      irfa <- array(0, c(k, k, horizon))
      irfa[,,1] <- B_hat
      Mm <- matrix(0, nrow = k*p, ncol = k*p)
      Mm[1:k, 1:(k*p)] <- A_hat
      Mm[(k+1):(k*p), 1 : ((p-1)*k)] <- diag(k*(p-1))
      Mm1 <- diag(k*p)
      for(i in 1:(horizon-1)){
        Mm1 <- Mm1%*%Mm
        irfa[,,(i+1)] <- Mm1[1:k, 1:k]%*%B_hat
      }
      return(irfa)
    }
  }

  if(x$type == 'const'){
    A_hat <- x$A_hat[,-1]
  }else if(x$type == 'trend'){
    A_hat <- x$A_hat[,-1]
  }else if(x$type == 'both'){
    A_hat <- x$A_hat[,-c(1,2)]
  }else{
    A_hat <- x$A_hat
  }

  B_hat <- x$B

  IR <- IrF(A_hat, B_hat, horizon)

  fe <- list()
  for(i in 1:nrow(B_hat)){
    fe[[i]] <- as.data.frame(t(IR[i,,]))
    colnames(fe[[i]]) <- colnames(x$y)
  }
  names(fe) <- colnames(x$y)
  fe2 <- fe

  for(i in 1:length(fe)){
    for(j in 1:horizon){
      fe2[[i]][j,] <- (colSums(fe[[i]][j:1,]^2)/sum(fe[[i]][j:1,]^2))*100
    }
  }

  class(fe2) <- "fevd"
  return(fe2)
}
