% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/imrf.R
\name{imrf}
\alias{imrf}
\title{Impulse Response Functions for SVAR Models}
\usage{
imrf(x, horizon = 20)
}
\arguments{
\item{x}{SVAR object of class "svars"}

\item{horizon}{Time horizon for the impulse responses}
}
\description{
Calculation of impulse response functions for an identified SVAR object 'svars' derived by function id.cvm( ),id.cv( ),id.dc( ) or id.ngml( ).
}
\examples{
\donttest{
v1 <- VAR(USA, lag.max = 10, ic = "AIC" )
x1 <- id.ngml(v1)
x2 <- imrf(x1, horizon = 20)
plot(x2)
}

}
\seealso{
\code{\link{id.cvm}}, \code{\link{id.dc}}, \code{\link{id.ngml}} or \code{\link{id.cv}}
}
