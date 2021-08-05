#!/usr/bin/env python

import argparse

from rtofdata.erd import create_erd
from rtofdata.excel import write_excel_specification
from rtofdata.spec_parser import parse_specification
from rtofdata.word import write_word_specification


def main():
    spec = parse_specification()

    create_erd(spec)
    write_word_specification(spec)
    write_excel_specification(spec)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Process the RTOF data specification'
    )
    parser.parse_args()
    main()