import numpy as np
from tensorflow.keras.models import load_model

# Load the trained model
model = load_model('sound_classification_model.h5')

# Get weights of the first dense layer
weights, biases = model.layers[0].get_weights()

# Quantize weights and biases (example using 8-bit quantization)
weights_q = np.round(weights * 127).astype(np.int8)
biases_q = np.round(biases * 127).astype(np.int8)

# Save weights and biases to a file
np.savetxt('generated_files/dense_weights21.txt', weights_q, fmt='%d')
np.savetxt('generated_files/dense_biases21.txt', biases_q, fmt='%d')

