# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np
import scipy.ndimage

colors = {
    'white': (255, 255, 255, 255),
    'black': (0, 0, 0, 255),
    'lime_green': (154, 214, 101, 255),
    'light_green': (223, 245, 135, 255),
    'aqua': (75, 206, 148, 255),
    'peach': (255, 234, 209, 255),
    'red': (237, 28, 36, 255)
}

image_path = 'map.png'
image = Image.open(image_path)
image = image.convert("RGBA")

image_array = np.array(image)

color_list = list(colors.values())
color_to_index = {v: k for k, v in enumerate(color_list)}

def get_color_index(color):
    return color_to_index.get(tuple(color), len(color_list) - 1)  # ostatni kolor jest domyslny

index_array = np.apply_along_axis(lambda pixel: get_color_index(pixel), 2, image_array)

neighborhood_size = 6

def most_frequent_color(indices):
    unique, counts = np.unique(indices, return_counts=True)
    most_frequent_index = unique[np.argmax(counts)]
    return color_list[most_frequent_index]

def process_pixel(x, y):
    x_min = max(0, x - neighborhood_size // 2)
    x_max = min(index_array.shape[0], x + neighborhood_size // 2 + 1)
    y_min = max(0, y - neighborhood_size // 2)
    y_max = min(index_array.shape[1], y + neighborhood_size // 2 + 1)
    neighborhood = index_array[x_min:x_max, y_min:y_max]
    return most_frequent_color(neighborhood)

processed_image_array = np.array([[process_pixel(x, y) for y in range(index_array.shape[1])] for x in range(index_array.shape[0])])

processed_image = Image.fromarray(np.uint8(processed_image_array))
processed_image_path = 'cleaned_image.png'
processed_image.save(processed_image_path)
processed_image.show()