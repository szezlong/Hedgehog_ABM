# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np

colors = {
    'black': (0, 0, 0, 255),
    'light_green': (223, 245, 135, 255),
    'dark_green': (154, 214, 101, 255),
    'blue_green': (75, 206, 148, 255),
    'wheat': (255, 234, 209, 255),
    'red': (255, 0, 0, 255)
}

image_path = 'map_resized.png'
image = Image.open(image_path)
image = image.convert("RGBA")
image_array = np.array(image)

color_list = list(colors.values())
color_to_index = {tuple(v): k for k, v in enumerate(color_list)}

def get_color_index(color):
    color_tuple = tuple(color)
    if color_tuple in color_to_index:
        return color_to_index[color_tuple]
    else:
        color_diffs = np.sum((np.array(color_list) - color) ** 2, axis=1)
        closest_color_index = np.argmin(color_diffs)
        return closest_color_index

index_array = np.apply_along_axis(lambda pixel: get_color_index(pixel), 2, image_array)

neighborhood_size = 6

def process_pixel(x, y):
    x_min = max(0, x - neighborhood_size // 2)
    x_max = min(index_array.shape[0], x + neighborhood_size // 2 + 1)
    y_min = max(0, y - neighborhood_size // 2)
    y_max = min(index_array.shape[1], y + neighborhood_size // 2 + 1)
    neighborhood = index_array[x_min:x_max, y_min:y_max]
    unique, counts = np.unique(neighborhood, return_counts=True)
    most_frequent_index = unique[np.argmax(counts)]
    return color_list[most_frequent_index]

processed_image_array = np.zeros((index_array.shape[0], index_array.shape[1], 4), dtype=np.uint8)
for x in range(index_array.shape[0]):
    for y in range(index_array.shape[1]):
        processed_image_array[x, y] = process_pixel(x, y)

processed_image = Image.fromarray(processed_image_array)
processed_image_path = 'map.png'
processed_image.save(processed_image_path)
processed_image.show()