#' Impulse Response Functions for SVAR Models
#'
#' Calculation of impulse response functions for an identified SVAR object
#'
#' @param x SVAR object of class "svars"
#' @param horizon Time horizon for the impulse responses
#'
#' @examples
#' \dontrun{
#'
#' x2 <- imrf(x1, horizon = 20)
#' plot(x2)
#' }
#'
#' @export

imrf <- function(x, horizon = 20){

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
  }else{
    A_hat <- x$A_hat
  }

  B_hat <- x$B

  IR <- IrF(A_hat, B_hat, horizon)

  impulse <- matrix(0, ncol = dim(IR)[2]^2 + 1, nrow = dim(IR)[3])
  cc <- 1
  impulse[,1] <- seq(1, dim(IR)[3])
  for(i in 1:dim(IR)[2]){
    for(j in 1:dim(IR)[2]){
      cc <- cc + 1
      impulse[,cc] <- IR[i,j,]
    }
  }
  impulse <- list(irf = as.data.frame(impulse))
  class(impulse) <- "irf"
  return(impulse)
}