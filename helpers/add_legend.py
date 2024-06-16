# -*- coding: utf-8 -*-

from PIL import Image, ImageDraw, ImageFont
import csv
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.cm import ScalarMappable

def add_gradient_legend_to_image(image_path, legend_csv_path, output_path):
    image = Image.open(image_path)

    legend_data = []
    max_visits = 0
    with open(legend_csv_path, newline='') as csvfile:
        reader = csv.reader(csvfile)
        next(reader)
        for row in reader:
            if len(row) >= 3:
                color_floats = tuple(map(float, row[0][1:-1].split(',')))
                color = tuple(int(c * 255) for c in color_floats)
                visits = float(row[1])
                percentage = float(row[2])
                legend_data.append((color, visits, percentage))
                if visits > max_visits:
                    max_visits = visits

    legend_data.sort(key=lambda x: x[2], reverse=True)

    gradient = np.linspace(0, 1, 256).reshape(1, 256)
    gradient = np.vstack((gradient, gradient))
    norm = Normalize(vmin=0, vmax=max_visits)
    sm = ScalarMappable(cmap='Reds_r', norm=norm)
    sm.set_array([])

    fig, ax = plt.subplots(figsize=(2, 4))
    ax.imshow(gradient, aspect='auto', cmap='Reds_r', origin='lower')
    ax.set_axis_off()

    cbar = fig.colorbar(sm, ax=ax)
    cbar.set_label('liczba wizyt')
    cbar.set_ticks([0, max_visits * 0.25, max_visits * 0.5, max_visits * 0.75, max_visits])
    cbar.set_ticklabels([f'{0:.0f}', f'{max_visits * 0.25:.0f}', f'{max_visits * 0.5:.0f}', f'{max_visits * 0.75:.0f}', f'{max_visits:.0f}'])

    fig.suptitle('Legenda', fontsize=12)
    plt.savefig('gradient_legend.png', bbox_inches='tight', pad_inches=0.1)
    plt.close(fig)

    legend_image = Image.open('gradient_legend.png')
    new_image = Image.new('RGB', (image.width + legend_image.width, max(image.height, legend_image.height)), (255, 255, 255))
    new_image.paste(image, (0, 0))
    new_image.paste(legend_image, (image.width, 0))
    new_image.save(output_path)

add_gradient_legend_to_image("result-map.png", "legend.csv", "final-map.png")