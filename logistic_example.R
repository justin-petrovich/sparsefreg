#####################################################################
#------- Example Using MISFIT for a Logistic SoF Model -------------#
#####################################################################


set.seed(123)

library(MASS)
library(fcr)
library(dplyr)
library(CompQuadForm)
library(sparsefreg)

## Data generation
M <- 100 # grid size
N <- 200
m <-2
J <- 2
K <- 10
w <- 1
var_delt <- 0.5
grid <- seq(from=0,to=1,length.out = M)
nfpc <- 2 # number of fpcs used for mu1
p <- 0.5
mu0 <- rep(0,M)
Cx_f<-function(t,s,sig2=1,rho=0.5){ # Matern covariance function with nu = 5/2
  d <- abs(outer(t,s,"-"))
  tmp2 <- sig2*(1+sqrt(5)*d/rho + 5*d^2/(3*rho^2))*exp(-sqrt(5)*d/rho)}
Cx <- Cx_f(grid,grid)
lam <- eigen(Cx,symmetric = T)$values/M
# lam <- eigen(C0,symmetric = T)$values
phi <- eigen(Cx,symmetric = T)$vectors*sqrt(M)
# phi <- eigen(C0,symmetric = T)$vectors
if(nfpc==1){
  mu1 <- phi[,1]*w
}else{
  mu1 <- rowSums(phi[,1:nfpc])*w
}

## Slope Function
if(nfpc==1){
  beta <- phi[,1]*(1/lam[1])*w
}else{
  beta <- phi[,1:nfpc]%*%(1/lam[1:nfpc])*w
  # beta <- phi%*%(c(t(mu1)%*%phi/M)/lam)
}
alpha <- log(p) - log(1 - p) - sum(((t(phi)%*%(mu1 - mu0)/M)^2)/(lam^2))/2

## Simulate Data
y <- sort(rbinom(N,1,p))
N_0 <- sum(y==0)
N_1 <- sum(y==1)
Xs_0 <- mvrnorm(N_0,mu0,Cx)
Xs_1 <- mvrnorm(N_1,mu1,Cx)
Xn_0 <- Xs_0 + rnorm(N_0*M,sd = sqrt(var_delt))
Xn_1 <- Xs_1 + rnorm(N_1*M,sd = sqrt(var_delt))
X_s <- rbind(Xs_0,Xs_1)
X_comp <- rbind(Xn_0,Xn_1)

Xi0 <- (Xs_0 - mu0)%*%phi/M
Xi1 <- (Xs_1 - mu1)%*%phi/M
Xi <- rbind(Xi0,Xi1)

X_mat<-matrix(nrow=N,ncol=m)
T_mat<-matrix(nrow=N,ncol=m)
ind_obs<-matrix(nrow=N,ncol=m)

for(i in 1:N){
  ind_obs[i,]<-sort(sample(1:M,m,replace=FALSE))
  X_mat[i,]<-X_comp[i,ind_obs[i,]]
  T_mat[i,]<-grid[ind_obs[i,]]
}

spt<-c(1,N_0+1)
ind_obs[spt,1] = 1; ind_obs[spt,m] = M
X_mat[spt,]<-X_comp[spt,ind_obs[spt[1],]]
T_mat[spt,]<-rbind(grid[ind_obs[spt[1],]],grid[ind_obs[spt[1],]])

## Create data frame for observed data
obsdf <- data.frame("X" = c(t(X_mat)),"argvals" = c(t(T_mat)),
                    "y" = rep(y,each = m),"subj" = rep(1:N,each = m))

user_params <- list(Cx = Cx, mu0 = mu0, mu1 = mu1,
                    var_delt = var_delt, lam = lam, phi = phi)

check <- misfit(obsdf,grid,K = K,J = J,family = "Binomial",k = 20,user_params = user_params,nPhi = 1)

plot(grid,beta,type = 'l')
lines(grid,check$beta.hat,lty = 2)

alpha
check$alpha.hat

par(mfrow = c(1,2))
matplot(x = grid,t(X_s[which(y==0),]),type = 'l',col = 'black')
lines(grid,mu0,col = 'black',lwd = 5)
matplot(x = grid,t(X_s[which(y==1),]),type = 'l',col = 'red',add = T)
lines(grid,mu1,col = 'red',lwd = 5)

matplot(x = grid,t(check$Xest[which(y==0),]),type = 'l',col = 'black')
lines(grid,check$params$mu0,col = 'black',lwd = 5)
matplot(x = grid,t(check$Xest[which(y==1),]),type = 'l',col = 'red',add = T)
lines(grid,mu1,col = 'red',lwd = 5)
par(mfrow = c(1,1))