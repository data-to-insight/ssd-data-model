#!/usr/bin/env python

import argparse

from rtofdata.spec_parser import parse_specification
from rtofdata.word import write_word_specification


def main():
    spec = parse_specification()
    # rules = generate_validation_rules(data)
    #
    # data['rules'] = rules
    #

    write_word_specification(spec)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Process the RTOF data specification'
    )
    parser.parse_args()
    main()