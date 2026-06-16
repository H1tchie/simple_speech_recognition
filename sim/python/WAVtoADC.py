import numpy as np
import librosa

def process_wav_to_adc(file_path, output_file, adc_bits=12):
    # Load the WAV file
    y, sr = librosa.load(file_path, sr=None)

    # Normalize the audio signal to the range of the ADC
    max_adc_value = (2 ** (adc_bits - 1)) - 1
    min_adc_value = -(2 ** (adc_bits - 1))
    
    # Normalize to [-1, 1]
    y = y / np.max(np.abs(y))
    
    # Scale to ADC range
    adc_data = np.int16(y * max_adc_value)

    adc_data = np.clip(adc_data, min_adc_value, max_adc_value)

    # Save to a text file
    with open(output_file, 'w') as f:
        for sample in adc_data:
            # Convert the sample to a 12-bit value in hexadecimal format
            hex_val = format(sample & 0xFFFF, '04x')  # Masking to ensure 12-bit value
            f.write(f"{hex_val}\n")


# Path to the WAV file
wav_file_path = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/test/otherrec.wav'
adc_output_file = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/generated_files/input_adcoff2.txt'

# Process and save the ADC-like data
process_wav_to_adc(wav_file_path, adc_output_file)

print(f"Processed ADC data from {wav_file_path} saved to {adc_output_file}")
