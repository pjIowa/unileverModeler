import csv
from dateutil import parser
import matplotlib.pyplot as plt
import numpy as np

def get_file_dict(file_name):
	price_dict = {}
	with open(file_name, newline='') as file:
		reader = csv.reader(file, delimiter=',')
		i = 0
		for row in reader:
			if i == 0:
				i+=1
				continue
			row_date = parser.parse(row[0])
			price_dict[row_date] = float(row[1])
	return price_dict

UL_A = get_file_dict("Unilever_AS.csv")
UL_L = get_file_dict("Unilever_LSE.csv")
EUR_GBP = get_file_dict("EURGBP.csv")

common_dates = list(UL_A.keys() & UL_L.keys() & EUR_GBP.keys())
common_dates.sort()

UL_A_prices = []
UL_L_prices = []
for common_date in common_dates:
	UL_A_prices.append(UL_A[common_date]*EUR_GBP[common_date])
	UL_L_prices.append(UL_L[common_date])

UL_A_rebased = np.array(UL_A_prices)/UL_A_prices[0]*100.0
UL_L_rebased = np.array(UL_L_prices)/UL_L_prices[0]*100.0

plt.plot(common_dates, UL_A_rebased, label="UL AS, in GBP")
plt.plot(common_dates, UL_L_rebased, label="UL LSE, in GBP")
plt.ylabel('prices rebased from start, %')
plt.legend(loc="upper left")
plt.show()

UL_A_log_ret = np.diff(np.log(UL_A_prices))
UL_L_log_ret = np.diff(np.log(UL_L_prices))

plt.plot(common_dates[1:], UL_A_log_ret, label="UL AS, in GBP")
plt.plot(common_dates[1:], UL_L_log_ret, label="UL LSE, in GBP")
plt.ylabel('log returns')
plt.legend(loc="upper left")
plt.show()