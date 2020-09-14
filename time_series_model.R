library(xts)
library(forecast)
library(rugarch)

# load unilever stock price in London
dat=read.table("Unilever_LSE.csv", header=TRUE, sep = ",")
UL_L=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# load unilever stock price in Amsterdam
dat=read.table("Unilever_AS.csv", header=TRUE, sep = ",")
UL_A=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# merge time series for common dates
UL = merge(UL_L, UL_A, join='inner')

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
# Regression with ARIMA(1,0,1) errors 

# Coefficients:
#          ar1      ma1    xreg
#       0.2071  -0.4506  0.8490
# s.e.  0.0551   0.0506  0.0072

# sigma^2 estimated as 6.691e-05:  log likelihood=18149.89
# AIC=-36291.78   AICc=-36291.78   BIC=-36265.44

# Meaning:
# (1-.2071B)*y_t = .8490*x_t + (1-.4506*B)*eps_t
# eps_t is white noise with standard deviation of .008180

resid = residuals(fit_arimax)
acf(resid)
Box.test(resid, lag = 10, type = "Ljung-Box")
# Result:
# X-squared = 8.4345, df = 10, p-value = 0.5865
# 
# Meaning:
# p > .05, so no autocorrelation remaining

acf(resid^2)
Box.test(resid^2, lag = 10, type = "Ljung-Box")
pacf(resid^2)
# Result:
# X-squared = 596.27, df = 10, p-value < 2.2e-16
# 
# Meaning:
# p < .01 means ARCH effect remaining,
# so the model has non-constant volatility from the arimax model
# acf shows significant lags up to lag 6 , pacf up to lag 4

# check GARCH(4,6) and ARMAX(1,1) model with normal distribution
spec_b = ugarchspec(variance.model=list(model="sGARCH" 
	, garchOrder=c(4,6)), 
	, mean.model=list(armaOrder=c(1,1)
		, external.regressors=as.matrix(x)))
fit_b = ugarchfit(data=y, spec=spec_b)
show(fit_b)
# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error    t value Pr(>|t|)
# mu      0.000095    0.000069   1.374008 0.169439 X
# ar1     0.130815    0.071512   1.829289 0.067356
# ma1    -0.334377    0.067454  -4.957144 0.000001
# mxreg1  0.869360    0.006950 125.083238 0.000000
# omega   0.000003    0.000001   4.450988 0.000009
# alpha1  0.179786    0.018023   9.975558 0.000000
# alpha2  0.036926    0.026386   1.399456 0.161676 X
# alpha3  0.000000    0.034596   0.000005 0.999996 X
# alpha4  0.000000    0.050657   0.000002 0.999998 X
# beta1   0.000001    0.201926   0.000007 0.999995
# beta2   0.384377    0.201783   1.904902 0.056793
# beta3   0.162215    0.044356   3.657075 0.000255
# beta4   0.000000    0.131446   0.000003 0.999998 X
# beta5   0.196206    0.160955   1.219010 0.222840 X
# beta6   0.000001    0.042404   0.000030 0.999976 X

# Meaning:
# p >> .01 for multiple coefficients,
# mu can be removed in mean model
# alpha 2,3,4 can be removed by setting p in variance model to 1
# beta 4,5,6 can be removed by setting q in variance model to 3
# re-run model with changes

# check GARCH(1,3) and ARMAX(0,1) model with normal distribution
spec_b = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(1,3)), 
	, mean.model=list(armaOrder=c(0,1)
		, include.mean=F
		, external.regressors=as.matrix(x)))
fit_b = ugarchfit(data=y, spec=spec_b, solver = 'nloptr')
show(fit_b)
plot(fit_b,which=9)
# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error  t value Pr(>|t|)
# ma1    -0.207861    0.016123 -12.8919 0.000000
# mxreg1  0.870203    0.006998 124.3588 0.000000
# omega   0.000002    0.000001   3.1220 0.001796
# alpha1  0.165050    0.013520  12.2082 0.000000
# beta1   0.186282    0.093394   1.9946 0.046089
# beta2   0.404061    0.070856   5.7025 0.000000
# beta3   0.216037    0.079948   2.7022 0.006888

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                     0.9559 0.32823
# Lag[2*(p+q)+(p+q)-1][2]    2.6159 0.07353
# Lag[4*(p+q)+(p+q)-1][5]    4.8860 0.11631
# d.o.f=1
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic  p-value
# Lag[1]                       8.655 0.003262
# Lag[2*(p+q)+(p+q)-1][11]    12.550 0.029013
# Lag[4*(p+q)+(p+q)-1][19]    16.472 0.055983
# d.o.f=4

# Meaning:
# p < .01 for most coefficients, p < .05 for all
# so model parameters have decent evidence
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are heavier tailed than norm,
# so a different distribution must be used

spec_c = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(1,6)), 
	, mean.model=list(armaOrder=c(0,1)
		, include.mean=F
		, external.regressors=as.matrix(x))
	, distribution.model="std")
fit_c = ugarchfit(data=y, spec=spec_c, solver = 'nloptr')
show(fit_c)
plot(fit_c,which=9)
# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error   t value Pr(>|t|)
# ma1    -0.207101    0.014559 -14.22508 0.000000
# mxreg1  0.876892    0.006654 131.78834 0.000000
# omega   0.000003    0.000001   4.22579 0.000024
# alpha1  0.163605    0.008618  18.98514 0.000000
# beta1   0.308999    0.082267   3.75606 0.000173
# beta2   0.227810    0.037983   5.99773 0.000000
# beta3   0.079860    0.094387   0.84609 0.397504
# beta4   0.000000    0.185853   0.00000 1.000000
# beta5   0.000000    0.126767   0.00000 1.000000
# beta6   0.176725    0.071474   2.47256 0.013415
# shape   5.226337    0.334007  15.64738 0.000000

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                      1.231 0.26723
# Lag[2*(p+q)+(p+q)-1][2]     2.814 0.05058
# Lag[4*(p+q)+(p+q)-1][5]     5.146 0.09461
# d.o.f=1
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic  p-value
# Lag[1]                       8.067 0.004508
# Lag[2*(p+q)+(p+q)-1][20]    17.394 0.050246
# Lag[4*(p+q)+(p+q)-1][34]    22.951 0.133047
# d.o.f=7

# Meaning:
# p < .05 for many parameters
# so model parameters have decent evidence
# those that are > .05 can be ignored, because they are insigificant
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are from std and shape parameter is significant,
# but let's check if the residuals are skewed

spec_d = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(1,6)), 
	, mean.model=list(armaOrder=c(0,1)
		, include.mean=F
		, external.regressors=as.matrix(x))
	, distribution.model="sstd")
fit_d = ugarchfit(data=y, spec=spec_d, solver = 'nloptr')
show(fit_d)
plot(fit_d,which=9)

# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error    t value Pr(>|t|)
# ma1    -0.207383    0.014517 -14.285044 0.000000
# mxreg1  0.877035    0.006646 131.969700 0.000000
# omega   0.000003    0.000001   4.071906 0.000047
# alpha1  0.162553    0.009289  17.500120 0.000000
# beta1   0.313141    0.082411   3.799751 0.000145
# beta2   0.217303    0.099255   2.189345 0.028572
# beta3   0.086885    0.111964   0.776005 0.437746
# beta4   0.000002    0.229736   0.000007 0.999994 X
# beta5   0.000000    0.135143   0.000000 1.000000 X
# beta6   0.174876    0.085571   2.043639 0.040989
# skew    1.035458    0.018325  56.504647 0.000000
# shape   5.255792    0.338637  15.520436 0.000000

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                      1.210 0.27137
# Lag[2*(p+q)+(p+q)-1][2]     2.809 0.05107
# Lag[4*(p+q)+(p+q)-1][5]     5.159 0.09365
# d.o.f=1
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic  p-value
# Lag[1]                       7.974 0.004744
# Lag[2*(p+q)+(p+q)-1][20]    17.447 0.049219
# Lag[4*(p+q)+(p+q)-1][34]    22.930 0.133827
# d.o.f=7

# Meaning:
# p < .05 for most parameters, which is decent evidence
# parameters that are >> .05 and near-zero estimates can be ignored for model
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are from sstd and both parameters are significant,
# so we can end analysis

# Final model:
# y is diff(log(UL AS)), x is diff(log(UL LSE))
# y_t - .877035*x_t  = (1-.207383B)*a_t
# a_t = sigma_t * eps_t
# eps_t ~ t_(df=5.255792,skew=1.035458)
# sigma_t^2 = .000003 + .162553*(a_(t-1))^2 + .313141*(sigma_(t-1))^2 
# + .217303*(sigma_(t-2))^2 + .086885*(sigma_(t-3))^2 + .174876*(sigma_(t-4))^2