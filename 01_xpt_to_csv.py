## Project1.py convert LLCP2024.XPT file into LLCP2024.cvs
import pandas as pd

# Read the XPT file
df = pd.read_sas("LLCP2024.XPT", format="xport")

# Save as CSV
df.to_csv("LLCP2024.csv", index=False)

print("Conversion complete: LLCP2024.XPT -> LLCP2024.csv")
print("Rows:", df.shape[0])
print("Columns:", df.shape[1])