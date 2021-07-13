#!/usr/bin/env python
 
import yaml
import argparse
from rtofdata.excel import read_excel
from rtofdata.word import write_word_specification
from rtofdata.yaml import write_yaml

def main(filename):
    data = read_excel(filename, as_list=["Categories"])
    write_word_specification(data, "output/specification.docx")
    write_yaml(data, "output/specification.yaml")
    


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process the RTOF data specification')
    parser.add_argument('filename', type=str, help='The filename to read')

    args = parser.parse_args()

    main(args.filename)