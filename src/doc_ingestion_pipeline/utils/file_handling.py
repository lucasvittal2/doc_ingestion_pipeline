import logging

import yaml


def read_yaml(path: str) -> dict:
    with open(path) as file:
        try:
            data = yaml.safe_load(file)
            return data
        except Exception as err:
            logging.error(f"Error reading YAML file: {err}")
            raise err
