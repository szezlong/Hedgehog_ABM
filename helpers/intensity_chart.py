# -*- coding: utf-8 -*-

import matplotlib.pyplot as plt
import numpy as np

def reproduction_intensity(current_month, current_day):
    if current_month == 3 and current_day >= 20:
        return (current_day - 20) / 40
    elif current_month == 4:
        return 0.25 + (current_day / 30) * 0.75
    elif current_month == 5 or (current_month == 6 and current_day <= 15):
        return 1
    elif current_month == 6 and current_day > 15:
        return 1 - ((current_day - 15) / 15) * 0.25
    elif current_month == 7:
        return 0.75 - (current_day / 30) * 0.5
    elif current_month == 8 and current_day <= 15:
      return 0.25 - (current_day / 15) * 0.25
    else:
        return 0

days = []
intensities = []

for month in range(1, 13):
    for day in range(1, 31):
      if month == 12 and day == 31:
            break
      days.append(f"{month}-{day}")
      intensities.append(reproduction_intensity(month, day))

plt.figure(figsize=(10, 5))
plt.plot(days, intensities, label='Reproduction Intensity')
plt.axhline(y=0, color='black', linestyle='--', linewidth=1)
plt.fill_between(days, intensities, where=[i > 0 for i in intensities], color='blue', alpha=0.3)

key_dates = ["3-20", "4-30", "6-15", "8-15"]
key_labels = ["21 marca", "1 maja", "15 czerwca", "15 sierpnia"]

month_names = ["Styczeń", "Marzec", "Kwiecień", "Maj", "Czerwiec", "Lipiec", "Sierpień", "Wrzesień", "Grudzień"]
months_to_show = [1, 3, 4, 5, 6, 7, 8, 9, 12]

month_ticks = [f"{month}-1" for month in months_to_show]
month_labels = [month_names[i] for i in range(len(month_ticks))]

plt.xticks(ticks=[days.index(date) for date in month_ticks], labels=month_labels, rotation=45)

for i, key_date in enumerate(key_dates):
    plt.text(days.index(key_date), reproduction_intensity(int(key_date.split('-')[0]), int(key_date.split('-')[1])) + 0.015,
             key_labels[i], color='red', ha='center', fontweight='bold', fontsize = 10)

plt.xlabel('Miesiąc')
plt.ylabel('Intensywność Reprodukcji')
plt.grid(True)
plt.tight_layout()

plt.show()