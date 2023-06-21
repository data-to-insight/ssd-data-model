import subprocess
import pandas as pd

# Run the tree command and capture the output
result = subprocess.run(['tree', '-L', '2', '-I', '.git|z_clean_up_tmp'], capture_output=True, text=True)

# Split the output into lines
lines = result.stdout.strip().split('\n')

# Process the lines to extract directory information
directories = []
for line in lines:
    path = line.split('├── ')[-1].strip()  # Modify the delimiter based on your system
    level = line.count('│   ')  # Modify the delimiter based on your system
    directories.append((path, level))

# Create a DataFrame from the directory information
df = pd.DataFrame(directories, columns=['Path', 'Level'])

# Print the DataFrame
print(df)
