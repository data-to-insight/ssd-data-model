import yaml

def write_yaml(data: dict, filename: str):
    with open(filename, 'wt') as file:
        yaml.dump(data, file)