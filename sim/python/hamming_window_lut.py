import numpy as np

def generate_hamming_window(N, bit_depth):
    # Generate the Hamming window coefficients
    hamming_window = 0.54 - 0.46 * np.cos(2 * np.pi * np.arange(N) / (N - 1))
    
    # Scale the coefficients to 16-bit signed fixed-point representation
    max_val = 2**(bit_depth - 1) - 1  # Max value for signed 16-bit integer (32767)
    min_val = -(2**(bit_depth - 1))   # Min value for signed 16-bit integer (-32768)
    
    hamming_window_fixed = np.round(hamming_window * max_val).astype(int)
    
    # Ensure values are within the signed 16-bit range
    hamming_window_fixed = np.clip(hamming_window_fixed, min_val, max_val)
    
    return hamming_window_fixed

# Parameters
N = 64  # Number of points in the window
bit_depth = 12 # 16-bit signed fixed-point representation

# Generate Hamming window coefficients
hamming_window_fixed = generate_hamming_window(N, bit_depth)

# Print the results in Verilog format
for i, coeff in enumerate(hamming_window_fixed):
    print(f"assign hamming_window[{i}] = 12'd{coeff};")




