# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np

image_path = 'map_pre.png'
image = Image.open(image_path)

new_width = image.width // 3
new_height = image.height // 3
new_size = (new_width, new_height)
resized_image = image.resize(new_size, Image.ANTIALIAS)
resized_image_path = 'map_resized.png'
resized_image.save(resized_image_path)

colors = {
    'turquoise': ( 22, 129, 97, 255 ),
    'turquoise+1': ( 74, 178, 147, 255),
    'green': (89, 176, 60, 255),
    'green+2': (155, 208, 138, 255),
    'lime': ( 86, 218, 98, 255),
    'yellow': (237, 237, 49, 255),
    'red': (215, 50, 41, 255),
    #'gray': (141, 141, 141, 255),
    #'violet': ( 124, 80, 164, 255),
    'black': (0, 0, 0, 255),
    'white': (255, 255, 255, 255)
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

neighborhood_size = 3

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