def convert_number(number):
    """
    Convert a decimal number to the required format:
    - If positive: 8'dXX,
    - If negative: -8'dXX,
    """
    if number >= 0:
        return f"8'd{number},"
    else:
        return f"-8'd{-number},"

def process_2d_array(input_file, output_file):
    """
    Process the input file to convert each number in a 2D array to the required format
    and write the result to the output file with exactly 64 numbers per line.
    """
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            # Split line by both commas and spaces, strip whitespace/newlines
            numbers = [num.strip() for num in line.replace(',', ' ').split() if num.strip()]
            
            # Convert each number to the required format
            converted_numbers = [convert_number(int(num)) for num in numbers]
            
            # Join numbers into a single line with 64 numbers per line
            for i in range(0, len(converted_numbers), 128):
                outfile.write(' '.join(converted_numbers[i:i+128]) + '\n')



# Define input and output files
input_file = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/generated_files/dense_biases21.txt'
output_file = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/generated_files/dense_biases21_rd.txt'

# Process the 2D array file
process_2d_array(input_file, output_file)
