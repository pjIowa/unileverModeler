library(xts)
library(forecast)
library(rugarch)

# load unilever stock price in London
dat=read.table("Unilever_LSE.csv", header=TRUE, sep = ",")
UL_L=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# load unilever stock price in Amsterdam
dat=read.table("Unilever_AS.csv", header=TRUE, sep = ",")
UL_A=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# load EUR to GBP fx rates
dat=read.table("EURGBP.csv", header=TRUE, sep = ",")
EURGBP=xts(dat$Adj_Close, order.by=as.Date(dat$Date, format="%m/%d/%Y"))

# get data for common dates across all three datasets
common_dates = as.Date(Reduce(intersect, list(index(EURGBP), index(UL_A), index(UL_L))))
UL_L = UL_L[common_dates]
# convert unilever amsterdam stock price from eur to gbp
UL_A = UL_A[common_dates]*EURGBP[common_dates]

# merge time series for common dates
UL = merge(UL_L, UL_A, join='inner')

# log to remove exponential 
# difference to remove autocorrelation
r = diff(log(UL))[-1]

# scatter plot to compare log returns
x = as.numeric(r$UL_L)
y = as.numeric(r$UL_A)
plot(x, y, xlab="Unilever L", ylab="Unilever A", main="Scatter plot of log returns")
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
#       0.1687  -0.5946  0.9013
# s.e.  0.0312   0.0262  0.0068

# sigma^2 estimated as 6.704e-05:  log likelihood=18049.58
# AIC=-36091.16   AICc=-36091.15   BIC=-36064.84

# Meaning:
# (1-.1687B)*y_t = .9013*x_t + (1-.5946*B)*eps_t
# eps_t is white noise with variance of 6.704e-05

resid = residuals(fit_arimax)
acf(resid)
Box.test(resid, lag = 5, type = "Ljung-Box")
# Result:
# X-squared = 6.2766, df = 5, p-value = 0.2802
# 
# Meaning:
# p > .05, so no autocorrelation remaining

acf(resid^2)
Box.test(resid^2, lag = 5, type = "Ljung-Box")
pacf(resid^2)
# Result:
# X-squared = 878.28, df = 5, p-value < 2.2e-16
# 
# Meaning:
# p < .01 means ARCH effect remaining,
# so the model has non-constant volatility from the arimax model
# acf shows significant lags up to lag 8, pacf up to lag 2

# after testing different models 
# I found GARCH(2,8) and ARMAX(1,1) model with normal distribution 
# avoided autocorrelation and non-constant variance 
# 2,3
spec_b = ugarchspec(variance.model=list(model="sGARCH" 
	, garchOrder=c(3,3)), 
	, mean.model=list(armaOrder=c(1,1)
		, external.regressors=as.matrix(x)))
fit_b = ugarchfit(data=y, spec=spec_b, solver = 'nloptr')
show(fit_b)
plot(fit_b,which=9)
# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error  t value Pr(>|t|)
# mu      0.000132    0.000044   3.0096 0.002616
# ar1     0.088305    0.032829   2.6898 0.007149
# ma1    -0.540836    0.027377 -19.7548 0.000000
# mxreg1  0.928256    0.006426 144.4570 0.000000
# omega   0.000003    0.000001   3.4272 0.000610
# alpha1  0.218060    0.018760  11.6237 0.000000
# alpha2  0.000000    0.002821   0.0000 1.000000 X
# alpha3  0.000000    0.014975   0.0000 1.000000 X
# beta1   0.391663    0.121860   3.2140 0.001309
# beta2   0.000000    0.169678   0.0000 1.000000 X
# beta3   0.360435    0.037697   9.5614 0.000000

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                     0.2644  0.6071
# Lag[2*(p+q)+(p+q)-1][5]    1.2481  0.9998
# Lag[4*(p+q)+(p+q)-1][9]    7.2816  0.1033
# d.o.f=2
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic p-value
# Lag[1]                       3.189 0.07416
# Lag[2*(p+q)+(p+q)-1][17]    11.714 0.20224
# Lag[4*(p+q)+(p+q)-1][29]    19.726 0.14629
# d.o.f=6

# Meaning:
# p < .01 for most coefficients
# so model parameters have decent evidence
# p > .05 for residuals means there is no autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are heavier tailed than norm,
# so a different distribution must be used

spec_c = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(5,5)), 
	, mean.model=list(armaOrder=c(2,1)
		, include.mean=F
		, external.regressors=as.matrix(x))
	, distribution.model="std")
fit_c = ugarchfit(data=y, spec=spec_c, solver = 'nloptr')
show(fit_c)
plot(fit_c,which=9)
# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error    t value Pr(>|t|)
# ar1     0.143764    0.047170   3.047791 0.002305
# ar2     0.033271    0.025344   1.312767 0.189261
# ma1    -0.588410    0.044174 -13.320175 0.000000
# mxreg1  0.935270    0.005861 159.578829 0.000000
# omega   0.000002    0.000001   4.669802 0.000003
# alpha1  0.208276    0.025881   8.047336 0.000000
# alpha2  0.000025    0.037329   0.000674 0.999462
# alpha3  0.000000    0.043653   0.000000 1.000000
# alpha4  0.000000    0.037063   0.000000 1.000000
# alpha5  0.000000    0.016885   0.000000 1.000000
# beta1   0.343714    0.176893   1.943063 0.052009
# beta2   0.040841    0.206502   0.197776 0.843220
# beta3   0.280879    0.226202   1.241717 0.214341
# beta4   0.000000    0.115700   0.000000 1.000000
# beta5   0.095848    0.120270   0.796940 0.425486
# shape   5.731026    0.399456  14.347065 0.000000

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                          statistic  p-value
# Lag[1]                       1.662 0.197391
# Lag[2*(p+q)+(p+q)-1][8]      6.559 0.001357
# Lag[4*(p+q)+(p+q)-1][14]    12.159 0.024026
# d.o.f=3
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic p-value
# Lag[1]                        4.30 0.03812
# Lag[2*(p+q)+(p+q)-1][29]     20.94 0.10173
# Lag[4*(p+q)+(p+q)-1][49]     30.05 0.18574
# d.o.f=10

# Meaning:
# p < .05 for many parameters
# so model parameters have decent evidence
# those that are > .05 can be ignored, because they are insigificant
# p > .01 and p < .05 for residuals means there is little autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are from std and shape parameter is significant,
# but let's check if the residuals are skewed

spec_d = ugarchspec(variance.model=list(model="sGARCH"
	, garchOrder=c(3,5)), 
	, mean.model=list(armaOrder=c(1,1)
		# , include.mean=F
		, external.regressors=as.matrix(x))
	, distribution.model="sstd")
fit_d = ugarchfit(data=y, spec=spec_d, solver = 'nloptr')
show(fit_d)
plot(fit_d,which=9)

# Result:
# Optimal Parameters
# ------------------------------------
#         Estimate  Std. Error    t value Pr(>|t|)
# mu      0.000072    0.000043   1.672999 0.094328
# ar1     0.086422    0.031268   2.763917 0.005711
# ma1    -0.530315    0.026655 -19.895273 0.000000
# mxreg1  0.936292    0.005919 158.193800 0.000000
# omega   0.000002    0.000001   4.664548 0.000003
# alpha1  0.203415    0.024901   8.168806 0.000000
# alpha2  0.000134    0.140017   0.000955 0.999238 X
# alpha3  0.000000    0.141814   0.000000 1.000000 X
# beta1   0.356892    0.633156   0.563672 0.572978
# beta2   0.009990    0.862529   0.011582 0.990759 X
# beta3   0.295053    0.168515   1.750896 0.079964
# beta4   0.000000    0.163541   0.000000 1.000000 X
# beta5   0.102554    0.113075   0.906950 0.364433
# skew    1.060114    0.021305  49.757834 0.000000
# shape   5.810244    0.410840  14.142335 0.000000

# Weighted Ljung-Box Test on Standardized Residuals
# ------------------------------------
#                         statistic p-value
# Lag[1]                      1.520 0.21756
# Lag[2*(p+q)+(p+q)-1][5]     2.791 0.60535
# Lag[4*(p+q)+(p+q)-1][9]     9.103 0.02173
# d.o.f=2
# H0 : No serial correlation

# Weighted Ljung-Box Test on Standardized Squared Residuals
# ------------------------------------
#                          statistic p-value
# Lag[1]                       4.905 0.02678
# Lag[2*(p+q)+(p+q)-1][23]    17.192 0.10674
# Lag[4*(p+q)+(p+q)-1][39]    26.692 0.10538
# d.o.f=8

# Meaning:
# p < .05 for most parameters, which is decent evidence
# parameters that are >> .05 and near-zero estimates can be ignored for model
# p > .01 and p < .05 for residuals means there is little autocorrelation remaining
# p > .05 for squared residuals means there is no ARCH effect remaining
# QQ plot shows that the residuals are from sstd and both parameters are significant,
# so we can end analysis

# Final model:
# y is diff(log(UL AS, pound price)), x is diff(log(UL LSE, pound price))
# (1-.086422B)(y_t - .936292*x_t)  = (1-.530315B)*a_t
# a_t = sigma_t * eps_t
# eps_t ~ t_(df=5.810244,skew=1.060114)
# sigma_t^2 = .000002 + .203415*(a_(t-1))^2 + .356892*(sigma_(t-1))^2 
# + .295053*(sigma_(t-3))^2 + .102554*(sigma_(t-5))^2

e = residuals(fit_d)
mean(abs(e))
sqrt(sum(e^2)/length(e))

# Result:
# .005701158
# .008212241
# Meaning:
# The first result is the mean absolute error, 
# second result is root mean square error
# for the mean prediction of the model

e = residuals(fit_d)
d = e^2 - sigma(fit_d)^2
mean(abs(d))
sqrt(sum(d^2)/length(d))

# Result:
# 7.299417e-05
# .0002163114
# Meaning:
# The first result is the mean absolute error, 
# second result is root mean square error
# for the variance prediction of the model

# plots log returns of UL AS vs predicted values from model
mu_hat = fitted(fit_d)
plt_dates = tail(common_dates,-1)
plot(plt_dates
	, y 
	, type = "l" 
	, xlab = "" 
	, ylab = "log return of UL AS"
	, main="Actual vs. fitted values")
lines(plt_dates
	, as.numeric(mu_hat) 
	, col = adjustcolor("blue", alpha.f = 0.5))
legend("bottomright"
	, bty = "n"
	, lty = c(1,1)
	, col = c("black", adjustcolor("blue", alpha.f = 0.5))
	, legend = c(expression(y[t]), expression(hat(mu)[t])))

# plots unstandardized residuals
resi = as.numeric(residuals(fit_d))
plot(plt_dates 
	, resi
	, type = "l"
	, xlab = ""
	, ylab = ""
	, main="Unstandardized residuals")