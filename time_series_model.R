library(xts)
library(forecast)
library(rugarch)

# load unilever stock price in Amsterdam
dat=read.table("Unilever_AS.csv", header=TRUE, sep = ",")
UL_A=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# load unilever stock price in London
dat=read.table("Unilever_LSE.csv", header=TRUE, sep = ",")
UL_L=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

plot(UL_L, main="Unilever London")
plot(UL_A, main="Unilever Amsterdam")

# merge time series, keeping common dates
UL = merge(UL_L,UL_A,join='inner')

plot(UL)
# https://stackoverflow.com/questions/6142944/how-can-i-plot-with-2-different-y-axes

# log to remove exponential 
# difference to remove autocorrelation
r = diff(log(UL))[-1]







# load unilever stock price in London
dat=read.table("Unilever_LSE.csv", header=TRUE, sep = ",")
UL_L=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# log to remove exponential 
# difference to remove autocorrelation
r = diff(log(UL_L))[-1]

# check for autocorrelation and ARCH effect 
acf(r)
Box.test(r, lag = 10, type = "Ljung-Box")
# Result:
# X-squared = 29.322, df = 10, p-value = 0.001105
# Meaning:
# p < .01, so autocorrelation remaining

# check for ARCH effect
acf(r^2)
Box.test(r^2, lag = 10, type = "Ljung-Box")
# Result:
# X-squared = 0.049191, df = 10, p-value = 1
# Meaning: 
# p > .05, no ARCH effect remaining, so volatility is constant

# check fit of ARIMA models 
fit=auto.arima(r, max.p = 20, max.q = 20, max.d = 2, ic="bic")
fit
# Result:
# ARIMA(0,0,0) with zero mean 
# sigma^2 estimated as 0.0004023:  log likelihood=20519.46
# AIC=-41036.92   AICc=-41036.92   BIC=-41029.9
# 
# Meaning:
# the fitted model is y_t = eps_t
# where eps_t is white noise with std. dev. of sqrt(0.0004023) = 0.02006

# check GARCH(1,1) model with normal distribution
spec_b = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(1,1))
	, mean.model=list(armaOrder=c(0,0)))
fit_b = ugarchfit(data=r, spec=spec_b)
show(fit_b)
# Result:
# Conditional Variance Dynamics 	
# ------------------------------------
# GARCH Model	: sGARCH(1,1)
# Mean Model	: ARFIMA(0,0,0)
# Distribution	: norm 
# ------------------------------------
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error  t value Pr(>|t|)
# mu      0.000514    0.000128   4.0258  5.7e-05
# omega   0.000002    0.000001   4.4399  9.0e-06
# alpha1  0.050485    0.005297   9.5315  0.0e+00
# beta1   0.936742    0.005326 175.8765  0.0e+00
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                     0.7881  0.3747
# Lag[2*(p+q)+(p+q)-1][2]    0.7899  0.5717
# Lag[4*(p+q)+(p+q)-1][5]    2.1166  0.5911
# d.o.f=0
# H0 : No serial correlation
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                  0.0007337  0.9784
# Lag[2*(p+q)+(p+q)-1][5] 0.0090731  1.0000
# Lag[4*(p+q)+(p+q)-1][9] 0.0210746  1.0000
# d.o.f=2
# 
# Meaning:
# p < .01 for all parameters, so they're all significant
# r_t - .000514 = a_t
# a_t = sigma_t * eps_t
# eps_t ~ N(0,1)
# sigma_t^2 = .000002 + .050485*(a_(t-1))^2 + .936742*(sigma_(t-1))^2
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining

plot(fit_b,which=9)
# Meaning:
# QQ plot shows that the residuals are not normal, so a different distribution must be used

# check GARCH(1,1) model with student-t distribution
spec_c = ugarchspec(variance.model=list(model="sGARCH" 
	, garchOrder=c(1,1)), 
	, mean.model=list(armaOrder=c(0,0))
	, distribution.model="std")
fit_c = ugarchfit(data=r, spec=spec_c)
show(fit_c)
# Result:
# Conditional Variance Dynamics 	
# ------------------------------------
# GARCH Model	: sGARCH(1,1)
# Mean Model	: ARFIMA(0,0,0)
# Distribution	: std 
# ------------------------------------
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error  t value Pr(>|t|)
# mu      0.000540    0.000114   4.7236  2.0e-06
# omega   0.000006    0.000001   4.1278  3.7e-05
# alpha1  0.083409    0.004558  18.2998  0.0e+00
# beta1   0.886911    0.005898 150.3688  0.0e+00
# shape   4.741825    0.210479  22.5287  0.0e+00
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                     0.4995  0.4797
# Lag[2*(p+q)+(p+q)-1][2]    0.5130  0.6875
# Lag[4*(p+q)+(p+q)-1][5]    1.8300  0.6591
# d.o.f=0
# H0 : No serial correlation
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                  0.0005786  0.9808
# Lag[2*(p+q)+(p+q)-1][5] 0.0105796  1.0000
# Lag[4*(p+q)+(p+q)-1][9] 0.0227790  1.0000
# d.o.f=2
# 
# Meaning:
# p < .01 for all parameters, so they're all significant
# r_t - .000540 = a_t
# a_t = sigma_t * eps_t
# eps_t ~ t_4.741825
# sigma_t^2 = .000006 + .083409*(a_(t-1))^2 + .886911*(sigma_(t-1))^2
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining

plot(fit_c,which=9)
# Meaning:
# QQ plot shows that the residuals match student-t distribution

# check GARCH(1,1) model with skewed student-t distribution
spec_d = ugarchspec(variance.model=list(model="sGARCH" 
	, garchOrder=c(1,1)), 
	, mean.model=list(armaOrder=c(0,0))
	, distribution.model="sstd")
fit_d = ugarchfit(data=r, spec=spec_d)
show(fit_d)
# Result:
# Conditional Variance Dynamics 	
# ------------------------------------
# GARCH Model	: sGARCH(1,1)
# Mean Model	: ARFIMA(0,0,0)
# Distribution	: sstd 
# ------------------------------------
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error  t value Pr(>|t|)
# mu      0.000542    0.000125   4.3328  1.5e-05
# omega   0.000006    0.000001   4.1125  3.9e-05
# alpha1  0.083456    0.004576  18.2387  0.0e+00
# beta1   0.886888    0.005898 150.3770  0.0e+00
# skew    1.000528    0.014626  68.4066  0.0e+00
# shape   4.739763    0.210343  22.5335  0.0e+00
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                     0.4999  0.4796
# Lag[2*(p+q)+(p+q)-1][2]    0.5134  0.6873
# Lag[4*(p+q)+(p+q)-1][5]    1.8304  0.6590
# d.o.f=0
# H0 : No serial correlation
# ------------------------------------
# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                  0.0005773  0.9808
# Lag[2*(p+q)+(p+q)-1][5] 0.0105850  1.0000
# Lag[4*(p+q)+(p+q)-1][9] 0.0227882  1.0000
# d.o.f=2

# Meaning:
# p < .01 for all parameters, so they're all significant
# r_t - .000542 = a_t
# a_t = sigma_t * eps_t
# eps_t ~ t_(df=4.739763,skew=1.000528)
# sigma_t^2 = .000006 + .083456*(a_(t-1))^2 + .886888*(sigma_(t-1))^2
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining

plot(fit_d,which=9)
# Meaning:
# QQ plot shows that the residuals match skewed student-t distribution

# load unilever stock price in Amsterdam
dat=read.table("Unilever_AS.csv", header=TRUE, sep = ",")
UL_A=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# merge time series for common dates
UL = merge(UL_L,UL_A,join='inner')

# log to remove exponential 
# difference to remove autocorrelation
r = diff(log(UL))[-1]

# scatter plot to compare log returns
x = as.numeric(r$UL_L)
y = as.numeric(r$UL_A)
plot(x,y,xlab="Unilever L", ylab="Unilever A", main="Scatter plot of log returns")
# Meaning: 
# As expected, there is strong correlation between the returns
# of the dual-listed shares

# fit arimax model on log returns with Unilever A as target, Unilevel L as predictor
fit_arimax = auto.arima(y, max.p=20, xreg = x, max.q = 20, max.d=3, ic="bic")
fit_arimax
# Result:
# Regression with ARIMA(0,0,1) errors 
# 
# Coefficients:
#           ma1    xreg
#       -0.0804  0.3795
# 
# sigma^2 estimated as 0.0001657
# 
# Meaning:
# y_t = .3795*x_t + (1-.0804*B)*eps_t
# eps_t is white noise with standard deviation of .01287

# TODO
resid = residuals(fit_arimax)
acf(resid)
Box.test(resid, lag = 10, type = "Ljung-Box")
# Result:
# X-squared = 15.052, df = 10, p-value = 0.1302
# 
# Meaning:
# p > .05, so no autocorrelation remaining

# TODO
acf(resid^2)
Box.test(resid^2, lag = 10, type = "Ljung-Box")
# Result:
# X-squared = 0.38415, df = 10, p-value = 1
# 
# Meaning:
# p > .05, so no ARCH effect remaining