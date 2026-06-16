# -*- coding: utf-8 -*-
"""
Created on Thu Jul 25 08:27:15 2024

@author: ferdek
"""

import numpy as np

def convert_decimal_to_hex(input_file, output_file):
    # Load the decimal values from the text file
    decimal_values = np.loadtxt(input_file, dtype=np.int16)

    # Convert the loaded decimal values to hexadecimal
    with open(output_file, 'w') as f:
        if decimal_values.ndim == 1:  # If the array is 1D
            for val in decimal_values:
                # Convert value to hexadecimal in U2 (16-bit)
                hex_val = format(val & 0xFFFF, '04x')
                f.write(f"{hex_val}\n")
        elif decimal_values.ndim == 2:  # If the array is 2D
            for row in decimal_values:
                hex_row = [format(val & 0xFFFF, '04x') for val in row]
                f.write(" ".join(hex_row) + "\n")
        else:
            raise ValueError("Unsupported number of dimensions for conversion.")

# Convert and save the weights
convert_decimal_to_hex('generated_files/dense24_weights.txt', 'generated_files/dense24_weights_hex.txt')
convert_decimal_to_hex('generated_files/dense24_biases.txt', 'generated_files/dense24_biases_hex.txt')
convert_decimal_to_hex('generated_files/dense23_weights.txt', 'generated_files/dense23_weights_hex.txt')
convert_decimal_to_hex('generated_files/dense23_biases.txt', 'generated_files/dense23_biases_hex.txt')
convert_decimal_to_hex('generated_files/dense22_weights.txt', 'generated_files/dense22_weights_hex.txt')
convert_decimal_to_hex('generated_files/dense22_biases.txt', 'generated_files/dense22_biases_hex.txt')
convert_decimal_to_hex('generated_files/dense21_weights.txt', 'generated_files/dense21_weights_hex.txt')
convert_decimal_to_hex('generated_files/dense21_biases.txt', 'generated_files/dense21_biases_hex.txt')
