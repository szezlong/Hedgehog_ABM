# -*- coding: utf-8 -*-
from PIL import Image
import numpy as np

image_path = 'map.png'
image = Image.open(image_path)
image = image.convert("RGBA")

image_array = np.array(image)

unique_colors = np.unique(image_array.reshape(-1, image_array.shape[2]), axis=0)
num_unique_colors = len(unique_colors)
num_unique_colors, unique_colors