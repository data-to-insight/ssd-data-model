# streamlit run /workspaces/ssd-data-model/ssd_upload.py [ARGUMENTS]

import streamlit as st
import pandas as pd

def main():
    st.title('File Upload Tutorial')

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
            dataframes[f'df_list{i+1}'] = df
            
        for df_name, dataframe in dataframes.items():
            st.write(f'{df_name}:')
            st.write(dataframe)

if __name__ == '__main__':
    main()
