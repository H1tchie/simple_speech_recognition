import numpy as np

# Define the range of inputs for the LUT
input_range = np.arange(-128, 128, dtype=np.int64)

# Generate the exponential values
# Scaling input range to avoid overflow in np.exp
exp_values = np.exp(input_range / 32.0) * (2**32)  # Scale and convert to fixed-point
exp_values = np.clip(exp_values, 0, 2**40 - 1).astype(np.uint64)  # Ensure values fit in 40-bit

# Extract bits [39:24] and convert to 16-bit values
lut_values = (exp_values >> 24) & 0xFFFF

# Convert to hexadecimal format and save to a file
with open('lut_hex.txt', 'w') as f_hex:
    for val in lut_values:
        hex_val = format(val, '04x')  # 16-bit hexadecimal
        f_hex.write(f"{hex_val}\n")

# Convert to decimal format and save to a file
with open('lut_dec.txt', 'w') as f_dec:
    for val in lut_values:
        f_dec.write(f"{val}\n")

print("LUT generation complete. Check 'lut_hex.txt' and 'lut_dec.txt' for results.")
