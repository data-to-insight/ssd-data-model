#!/usr/bin/env python

import argparse
import base64
from pathlib import Path

import requests


def main(input_file:str, webhook_url: str):
    input_file = Path(input_file)

    with open(input_file, 'rb') as file:
        file_contents = base64.b64encode(file.read()).decode("ASCII")
    post_body = dict(filename=input_file.name, body=file_contents)
    response = requests.post(webhook_url, json=post_body)
    response.raise_for_status()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Upload a file to the publish webhook'
    )
    parser.add_argument("input", type=str, help="The input file")
    parser.add_argument("url", type=str, help="The webhook url")
    args = parser.parse_args()

    main(args.input, args.url)