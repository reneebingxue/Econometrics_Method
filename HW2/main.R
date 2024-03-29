#File: EMM_Assignment2.R
#Project: Assignment 2 for Econometrics Methods (Inference & Bootstrap)
#Author: Bingxue Li
#Date: 2024-02-03

# Setup -------------------------------------------------------------------
### CLEAN UP MY ENVIRONMENT
cat("\014")
library(numDeriv) 	# loads the functions grad and hessian which numerically evaluate the gradient and hessian
rm(list=ls()) 		# Clear workspace
set.seed(1) 		# Set seed for random number generator
# My working directory
setwd('/Users/renee/Desktop/Assignment2') 

###################################
# Part.I: Empirical Dist Function #
###################################
x = c(0,1,2)
B = 10
T3 = rep(0,B)
for(b in 1:B){
  index_b = sample(length(x),length(x),replace=TRUE)
  x_b = x[index_b]
  T3[b] = mean(x_b)
}
frequency <- table(T3)
ratio <- frequency / length(T3)
print(ratio)

B = 100
T3 = rep(0,B)
for(b in 1:B){
  index_b = sample(length(x),length(x),replace=TRUE)
  x_b = x[index_b]
  T3[b] = mean(x_b)
}
frequency <- table(T3)
ratio <- frequency / length(T3)
print(ratio)

B = 1000
T3 = rep(0,B)
for(b in 1:B){
  index_b = sample(length(x),length(x),replace=TRUE)
  x_b = x[index_b]
  T3[b] = mean(x_b)
}
frequency <- table(T3)
ratio <- frequency / length(T3)
print(ratio)
#############################
# Part.II: BOOTSTRAPPED MLE #
#############################
# Load the log-likelihood
source("OP_LL.R") #MLE
source("OP_NLS.R") #NLLSE
source("OP_GMMe.R") #JustID-GMM
source("OP_GMMh.R") #OverID-GMM
source("OP_LL_bnull.R")  #Constrained MLE
source("Probit_LL_grad.R") #Gradient(Score)
source("J_1.R") #Information matrix based on gradient
num = 1000		# Number of Monte Carlo iterations
B = 399       # Number of Bootstrap samples
alpha1 = 0    # True Parameter
alpha2 = 1    # True Parameter
beta = 1     # True Parameter 
theta = c(alpha1,alpha2,beta) # True parameter vector
k = length(theta) # Parameter Space Dim

theta_hat_ML_vec = matrix(0,num,k)  # Matrix to store MLE
J_2_inv = matrix(0,k,k)             # Averaged MLE Variance-Covariance Matrix
J_inv_boot = matrix(0,k,k)          # Averaged Bootstrap-MLE Variance-Covariance Matrix
#
for (it in 1:num) {
  n = 300
  # Data generating process
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)

  # With Original Sample: Comparison Baseline
  # call the OP_LL function to obtain ml estimators
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_ML = result$par
  # store ml estimator for simulation it
  theta_hat_ML_vec[it,1:k] = theta_hat_ML
  # k by k matrix for variance
  J_2_inv = J_2_inv + solve(result$hessian)/n

  # Bootstrap over 399 resampling
  theta_hat_ML_boot = matrix(0,B,k) #initialize bootstrap coefficient matrix
  for (b in 1:B) {
    # random sampling of indices with replacement from 1 to the length(y).
    index_b <- sample(length(y),length(y),replace=TRUE)
    # subset vector y and x using the indices generated
    y_b <- y[index_b]
    x_b <- x[index_b]
    dat_b = data.frame(x_b,y_b)
    # optimization using the BFGS for MLE
    result <- optim(par = theta, OP_LL, y = y_b, x = x_b, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
    theta_hat_ML_boot[b,1:k] = result$par}
    J_inv_boot = J_inv_boot + var(theta_hat_ML_boot)
}
# Average of theta_hat (original sample) over Monte Carlo iterations
colMeans(theta_hat_ML_vec)
# Average of theta_hat (bootstrapped)
colMeans(theta_hat_ML_boot)
# Average of bootstrap estimator of the variance (MLE)
J_inv_boot/num
# Average of variance estimate based on J_2 (MLE)
J_2_inv/num

######################################################################################
#Part.III: Verifying Robustness (Consistency Performance) of 4 Estimators: A NEW DGP #
######################################################################################
theta_hat_ML_vec = matrix(0,num,k)
theta_hat_NLS_vec = matrix(0,num,k)
theta_hat_GMMe_vec = matrix(0,num,k)
theta_hat_GMMh_vec = matrix(0,num,k)
inside_N_ML = rep(0,num)
inside_N_NLS = rep(0,num)
inside_N_GMMe = rep(0,num)
inside_N_GMMh = rep(0,num)
epsilon = 0.1
for (it in 1:num) {
  n = 300
  # Data generating process
  x = rnorm(n,0.5,1) 	# regressor
  prob_y0= 0.25 * pnorm(alpha2 - beta * x) + 0.75 * pnorm(alpha1 - beta * x)
  prob_y1= 0.5 * pnorm(alpha2 - beta * x) - 0.5 * pnorm(alpha1 - beta * x)
  prob_y2= 1 - 0.75 * pnorm(alpha2 - beta * x) - 0.25 * pnorm(alpha1 - beta * x)
  prob_y <- cbind(prob_y0,prob_y1,prob_y2)
  y <- apply(prob_y, 1, function(p) sample(0:2, size = 1, prob = p))

  # ML
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_ML = result$par
  # store ml estimator for simulation it
  theta_hat_ML_vec[it,1:k] = theta_hat_ML
  # count if the estimator is close enough to true para
  if (sqrt(sum((theta_hat_ML - theta)^2)) < epsilon) {
    inside_N_ML[it] = 1
  }

  # NLS
  result <- optim(par = theta, OP_NLS, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_NLS = result$par
  theta_hat_NLS_vec[it,1:k] = theta_hat_NLS
  if (sqrt(sum((theta_hat_NLS - theta)^2)) < epsilon) {
    inside_N_NLS[it] = 1
    }

  # GMMe
  result <- optim(par = theta, OP_GMMe, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_GMMe = result$par
  theta_hat_GMMe_vec[it,1:k] = theta_hat_GMMe
  if (sqrt(sum((theta_hat_GMMe - theta)^2)) < epsilon) {
    inside_N_GMMe[it] = 1
    }

  # GMMh
  result <- optim(par = theta, OP_GMMh, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_GMMh = result$par
  theta_hat_GMMh_vec[it,1:k] = theta_hat_GMMh
  if (sqrt(sum((theta_hat_GMMh - theta)^2)) < epsilon) {
    inside_N_GMMh[it] = 1
  }
}

# Averages
colMeans(theta_hat_ML_vec)
colMeans(theta_hat_NLS_vec)
colMeans(theta_hat_GMMe_vec)
colMeans(theta_hat_GMMh_vec)
# (Estimated) Probability that theta_hat lies inside a neighborhood around theta_0
mean(inside_N_ML)
mean(inside_N_NLS)
mean(inside_N_GMMe)
mean(inside_N_GMMh)

# One need to modify the functions according to the DGP for regression models to satisfy the underlying assumption

#############################
# Part.IV: Trinity of Tests #
#############################
set.seed(1)
theta_hat_vec = matrix(0,num,k) # Nonrestricted MLE outcomes
theta_hat0_vec = matrix(0,num,k)# Restricted MLE outcomes
Wald_vec = matrix(0,num,1)
reject_Wald = matrix(0,num,1)   # initialize Matrix HT outcome for iterations
reject_Score = matrix(0,num,1)  # initialize Matrix HT outcome for iterations
reject_LR = matrix(0,num,1)     # initialize Matrix HT outcome for iterations
cv = qchisq(.95, df=1)          # critical value corresponds to 1 restriction
theta=c(alpha1,alpha2,beta)     # Nonrestricted MLE Inputs
theta_null=c(alpha1,alpha2)     # Initialize Restricted MLE Inputs under null

#Test: H0: beta_0=1-------------------------------------------------------------
for (it in 1:num) {
  # Data generating process
  n = 300
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)
  
  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  theta_hat_vec[it,1:k] = theta_hat
  # MLE: Restricted under the null
  # MLE: Restricted under the null
  result_null <- optim(par = theta_null, OP_LL_bnull, y = y, x = x, b0 = 1, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_null = c(result_null$par,1)
  
  # Wald 
  theta_null = c(theta_hat[1],theta_hat[2],1)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  Wald_vec[it] = Wald
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }

  # Score
  Score = Probit_LL_grad(y,x,theta_hat_null)
  Score = n * t(Score)%*%solve(J_1(y,x,theta_hat_null))%*% Score
  if (is.nan(Score) == 0) {
    if (Score > cv) {
      reject_Score[it] = 1
    }
  }
  
  # LR
  LR = 2*n*(OP_LL_bnull(y,x,theta_hat_null,b0=1)-OP_LL(y,x,theta_hat))
  if (is.nan(LR) == 0) {
    if (LR > cv) {
      reject_LR[it] = 1
    }
  }
}

mean(reject_Wald)
mean(reject_Score)
mean(reject_LR)

#Test: H0 beta_0=0.9------------------------------------------------------------
set.seed(1)
theta_hat_vec = matrix(0,num,k) # Nonrestricted MLE outcomes
theta_hat0_vec = matrix(0,num,k)# Restricted MLE outcomes
Wald_vec = matrix(0,num,1)
reject_Wald = matrix(0,num,1)   # initialize Matrix HT outcome for iterations
reject_Score = matrix(0,num,1)  # initialize Matrix HT outcome for iterations
reject_LR = matrix(0,num,1)     # initialize Matrix HT outcome for iterations
cv = qchisq(.95, df=1)          # critical value corresponds to 1 restriction
theta=c(alpha1,alpha2,beta)     # Nonrestricted MLE Inputs
theta_null=c(alpha1,alpha2)   # Initialize Restricted MLE Inputs under null

for (it in 1:num) {
  # Data generating process
  n = 300
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)
  
  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  theta_hat_vec[it,1:k] = theta_hat
  # MLE: Restricted under the null
  result_null <- optim(par = theta_null, OP_LL_bnull, y = y, x = x, b0 = 0.9, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_null = c(result_null$par,0.9)
  
  # Wald 
  theta_null = c(theta_hat[1],theta_hat[2],0.9)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  Wald_vec[it] = Wald
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }
  
  # Score
  Score = Probit_LL_grad(y,x,theta_hat_null)
  Score = n * t(Score)%*%solve(J_1(y,x,theta_hat_null))%*% Score
  if (is.nan(Score) == 0) {
    if (Score > cv) {
      reject_Score[it] = 1
    }
  }
  
  # LR
  LR = 2*n*(OP_LL_bnull(y,x,theta_hat_null,b0=0.9)-OP_LL(y,x,theta_hat))
  if (is.nan(LR) == 0) {
    if (LR > cv) {
      reject_LR[it] = 1
    }
  }
}
#Test: H0 beta_0=0.9
mean(reject_Wald)
mean(reject_Score)
mean(reject_LR)

#Test: H0 beta_0=1.1------------------------------------------------------------
set.seed(1)
theta_hat_vec = matrix(0,num,k) # Nonrestricted MLE outcomes
theta_hat0_vec = matrix(0,num,k)# Restricted MLE outcomes
Wald_vec = matrix(0,num,1)
reject_Wald = matrix(0,num,1)   # initialize Matrix HT outcome for iterations
reject_Score = matrix(0,num,1)  # initialize Matrix HT outcome for iterations
reject_LR = matrix(0,num,1)     # initialize Matrix HT outcome for iterations
cv = qchisq(.95, df=1)          # critical value corresponds to 1 restriction
theta=c(alpha1,alpha2,beta)     # Nonrestricted MLE Inputs
theta_null=c(alpha1,alpha2)   # Initialize Restricted MLE Inputs under null
for (it in 1:num) {
  # Data generating process
  n = 300
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)
  
  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  theta_hat_vec[it,1:k] = theta_hat
  # MLE: Restricted under the null
  result_null <- optim(par = theta_null, OP_LL_bnull, y = y, x = x, b0 = 1.1, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat_null = c(result_null$par,1.1)
  
  # Wald 
  theta_null = c(theta_hat[1],theta_hat[2],1.1)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  Wald_vec[it] = Wald
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }
  
  # Score
  Score = Probit_LL_grad(y,x,theta_hat_null)
  Score = n * t(Score)%*%solve(J_1(y,x,theta_hat_null))%*% Score
  if (is.nan(Score) == 0) {
    if (Score > cv) {
      reject_Score[it] = 1
    }
  }
  
  # LR
  LR = 2*n*(OP_LL_bnull(y,x,theta_hat_null,b0=1.1)-OP_LL(y,x,theta_hat))
  if (is.nan(LR) == 0) {
    if (LR > cv) {
      reject_LR[it] = 1
    }
  }
}
#Test: H0 beta_0=1.1
mean(reject_Wald)
mean(reject_Score)
mean(reject_LR)

##################################
# Part.V: Bootstrapped Inference #
##################################
#Test: H0 beta_0=1------------------------------------------------------------
set.seed(1)
reject_Wald = matrix(0,num,1)
reject_Wald_boot = matrix(0,num,1)
B = 399
cv = qchisq(.95, df=1) 
num=1000
for (it in 1:num) {
  # Data generating process
  n = 300
  # Data generating process
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)

  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  
  # Wald
  theta_null = c(theta_hat[1],theta_hat[2],1)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }
  
  Wald_boot = rep(0,B)
  for (b in 1:B) {
    index_b <- sample(length(y),length(y),replace=TRUE)
    y_b <- y[index_b]
    x_b <- x[index_b]
    result <- optim(par = theta, OP_LL, y = y_b, x = x_b, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
    theta_b = result$par
    temp_b = theta_b[3] - theta_hat[3]
    V_hat_b <- solve(result$hessian)
    Wald_b = n*t(temp_b)%*%solve(V_hat_b[3,3])%*%temp_b
    Wald_boot[b] = Wald_b
  }

  Wald_boot <- sort(Wald_boot)
  cv_b <- Wald_boot[floor(B*0.95)]

  if (is.nan(Wald) == 0) {
    if (Wald > cv_b) {
      reject_Wald_boot[it] = 1
    }
  }
}
mean(reject_Wald)
mean(reject_Wald_boot)

#Test: H0 beta_0=0.9------------------------------------------------------------
set.seed(1)
reject_Wald = matrix(0,num,1)
reject_Wald_boot = matrix(0,num,1)
B = 399
cv = qchisq(.95, df=1) 
num=1000
for (it in 1:num) {
  # Data generating process
  n = 300
  # Data generating process
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)
  
  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  
  # Wald
  theta_null = c(theta_hat[1],theta_hat[2],0.9)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }
  
  Wald_boot = rep(0,B)
  for (b in 1:B) {
    index_b <- sample(length(y),length(y),replace=TRUE)
    y_b <- y[index_b]
    x_b <- x[index_b]
    result <- optim(par = theta, OP_LL, y = y_b, x = x_b, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
    theta_b = result$par
    temp_b = theta_b[3] - theta_hat[3]
    V_hat_b <- solve(result$hessian)
    Wald_b = n*t(temp_b)%*%solve(V_hat_b[3,3])%*%temp_b
    Wald_boot[b] = Wald_b
  }
  
  Wald_boot <- sort(Wald_boot)
  cv_b <- Wald_boot[floor(B*0.95)]
  
  if (is.nan(Wald) == 0) {
    if (Wald > cv_b) {
      reject_Wald_boot[it] = 1
    }
  }
}

mean(reject_Wald)
mean(reject_Wald_boot)

#Test: H0 beta_0=1.1------------------------------------------------------------
set.seed(1)
reject_Wald = matrix(0,num,1)
reject_Wald_boot = matrix(0,num,1)
B = 399
cv = qchisq(.95, df=1) 
num=1000
for (it in 1:num) {
  # Data generating process
  n = 300
  # Data generating process
  x = rnorm(n,0.5,1) 	   # regressor
  u = rnorm(n,0,1)		   # error term
  y_star = x * beta + u	 # latent "utility"
  y = rep(0,n)				   # observed outcome
  is_one = as.logical((y_star>alpha1) * (y_star<=alpha2)) # element-wise logical operations, indicating whether or not in the range alpha1 and 2
  y[is_one] = rep(1,sum(is_one))
  is_two = (y_star>alpha2)
  y[is_two] = rep(2,sum(is_two))
  dat = data.frame(x,y)
  
  # Estimation MLE: Nonrestricted
  result <- optim(par = theta, OP_LL, y = y, x = x, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
  theta_hat = result$par
  
  # Wald
  theta_null = c(theta_hat[1],theta_hat[2],1.1)
  temp = theta_hat[3] - theta_null[3]
  V_hat <- solve(result$hessian)
  Wald = n*t(temp)%*%solve(V_hat[3,3])%*%temp
  if (is.nan(Wald) == 0) {
    if (Wald > cv) {
      reject_Wald[it] = 1
    }
  }
  
  Wald_boot = rep(0,B)
  for (b in 1:B) {
    index_b <- sample(length(y),length(y),replace=TRUE)
    y_b <- y[index_b]
    x_b <- x[index_b]
    result <- optim(par = theta, OP_LL, y = y_b, x = x_b, method = c("BFGS"), control = list(reltol=1e-9), hessian=TRUE)
    theta_b = result$par
    temp_b = theta_b[3] - theta_hat[3]
    V_hat_b <- solve(result$hessian)
    Wald_b = n*t(temp_b)%*%solve(V_hat_b[3,3])%*%temp_b
    Wald_boot[b] = Wald_b
  }
  
  Wald_boot <- sort(Wald_boot)
  cv_b <- Wald_boot[floor(B*0.95)]
  
  if (is.nan(Wald) == 0) {
    if (Wald > cv_b) {
      reject_Wald_boot[it] = 1
    }
  }
}

mean(reject_Wald)
mean(reject_Wald_boot)
