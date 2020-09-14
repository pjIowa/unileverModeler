# Unilever Time Series Analysis

Unilever has had a dual listing in the UK and Netherlands since 1930. Since shareholders run the company as a single business, I want to validate whether the returns of the two stocks move in tandem. Graphs, stats, and discussion below. I was inspired to run this comparison after taking Financial Data Science (CFRM 502) in the University of Washington Computational Finance Program, taught by Professor Bahman Angoshtari, in Winter 2020.

### Prices of listings
![Unilever joint](images/Unilever_joint.png)

### Log returns of listings
![Unilever joint_log_returns](images/Unilever_joint_log_ret.png)


### Model for UL_A using UL_L
y is the log returns of Unilever Amsterdam, x is the same for Unilever London

y_t - .877035*x_t  = (1-.207383B)*a_t

a_t = sigma_t * eps_t

eps_t ~ t_(df=5.255792,skew=1.035458)

sigma_t^2 = .000003 + .162553*(a_(t-1))^2 + .313141*(sigma_(t-1))^2 + .217303*(sigma_(t-2))^2 + .086885*(sigma_(t-3))^2 + .174876*(sigma_(t-4))^2

TODO
calculate MAPE
https://stats.stackexchange.com/questions/194453/interpreting-accuracy-results-for-an-arima-model-fit

plot fitted model vs UL_A 
https://stats.stackexchange.com/questions/158493/how-to-compare-arima-model-in-r-to-actual-observations-used-to-create-the-model

plot residuals
https://otexts.com/fpp3/regarima.html

Discussion:
I expected that mean returns are nearly the same and near constant volatility, since traders would take advantage of the arbitrage. However, differencies in the UK/EU laws, market participants, and currencies could create a discrepancy, especially with Brexit in 2016.

Data: Adjusted close price is used for each stock. The prices for Unilever Amsterdam and London are from 5/10/1999 til 8/7/2020 inclusive.

Formula Image Generator: https://www.codecogs.com/latex/eqneditor.php
