# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np

target_colors = {
    'light_green': (44, 209, 59, 255),
    'dark_green': (89, 176, 60, 255),
    'blue_green': (29, 159, 120, 255),
    'wheat': (237, 237, 49, 255),
    'red': (215, 50, 41, 255)
}

def remap_colors(image, color_mapping):
    data = np.array(image)
    
    for color_name, original_color in color_mapping.items():        
        new_color = target_colors[color_name]
        mask = np.all(data == original_color, axis=-1)
        data[mask] = new_color
    
    new_image = Image.fromarray(data)
    return new_image

image_path = "map.png"
image = Image.open(image_path)

new_image = remap_colors(image, colors)
new_image_path = "map_color_fixed.png"
new_image.save(new_image_path)
