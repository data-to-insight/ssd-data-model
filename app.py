import streamlit as st
import pandas as pd

def main():
    st.title('File Upload Tutorial')

    multiple_files = st.file_uploader(
        "Multiple File Uploader", 
        accept_multiple_files=True
    )
    if multiple_files:
        dataframes = []
        for file in multiple_files:
            file.seek(0)
            dataframes.append(pd.read_csv(file))
            
        for i, dataframe in enumerate(dataframes):
            st.write(f'Dataframe {i+1}:')
            st.write(dataframe)

if __name__ == '__main__':
    main()
