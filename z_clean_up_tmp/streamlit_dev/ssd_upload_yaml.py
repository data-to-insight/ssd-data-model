import os
import sys
import streamlit as st
import pandas as pd


print(st.write(sys.version))


# Attempt to import yaml. If it fails, prompt user to install it.
try:
    import yaml
except ModuleNotFoundError:
    st.error("Please install the 'pyyaml' package using pip and restart the app.")
    st.stop()

def main():
    st.title('File Upload Tutorial')

    df_names = ["identity", "earlyhelp", "referrals", "assessments"]
    multiple_files = st.file_uploader(
        "Multiple File Uploader", 
        accept_multiple_files=True
    )
    if multiple_files:
        dataframes = {}
        for i, file in enumerate(multiple_files):
            file.seek(0)
            # skip the first 3 rows, so the data reading starts from row 4
            df = pd.read_csv(file, skiprows=3)
            # change column names to lowercase
            df.rename(str.lower, axis='columns', inplace=True)
            # load corresponding yaml file
            with open(f"data/records/{df_names[i]}.yml", 'r') as stream:
                config = yaml.safe_load(stream)
            # select only the columns defined in yaml file
            df = df[config["columns"]]
            dataframes[df_names[i]] = df
            
        for df_name, dataframe in dataframes.items():
            st.write(f'{df_name}:')
            st.write(dataframe)

if __name__ == '__main__':
    main()
