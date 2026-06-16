import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model, Model

# Load the trained model
model = load_model('sound_classification_model1.h5')

# Ensure the model is compiled
if not model.compiled:
    print("Model is not compiled. Compiling now...")
    model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# Force model initialization by making a dummy prediction
dummy_input = np.zeros((1, model.input_shape[1]))  # Adjust dimensions if needed
try:
    model.predict(dummy_input)
    print("Model successfully predicted with dummy input.")
except Exception as e:
    print(f"Error during dummy prediction: {e}")

# Print out the details of each layer
print("Model layers:")
for i, layer in enumerate(model.layers):
    print(f"Layer Index: {i}")
    print(f"Layer Name: {layer.name}")
    if hasattr(layer, 'input_shape'):
        print(f"Input Shape: {layer.input_shape}")
    if hasattr(layer, 'output_shape'):
        print(f"Output Shape: {layer.output_shape}")
    print("---")

# Alternative way to get logits by creating a new model that outputs intermediate layer
def get_logits_model(original_model, dense_70):
    # Try to find the layer by name
    logits_layer = None
    for layer in original_model.layers:
        if layer.name == dense_70:
            logits_layer = layer
            break

    if logits_layer is None:
        raise ValueError(f"Layer with name '{dense_70}' not found.")

    try:
        logits_model = Model(inputs=original_model.input, outputs=logits_layer.output)
        return logits_model
    except Exception as e:
        print(f"Error creating logits model: {e}")
        raise

# Use the name of the penultimate Dense layer before the output layer
dense_70 = 'dense_3'  # Adjust according to your actual penultimate layer name

try:
    logits_model = get_logits_model(model, dense_70)
    print("Logits model created successfully.")
except ValueError as e:
    print(f"Error creating logits model: {e}")

# Load test data
X_test = np.load('X_test.npy')

# Get logits
try:
    logits = logits_model.predict(X_test)
    # Print logits range
    max_logit = np.max(logits)
    min_logit = np.min(logits)
    print(f"Logits range: min = {min_logit}, max = {max_logit}")

    # Optionally, save logits to a file
    np.savetxt('logits.txt', logits, fmt='%f')
except Exception as e:
    print(f"Error during logits extraction: {e}")
