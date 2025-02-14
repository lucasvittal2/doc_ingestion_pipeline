import logging
import os
import shutil

import yaml


def read_yaml(path: str) -> dict:
    with open(path) as file:
        try:
            data = yaml.safe_load(file)
            return data
        except Exception as err:
            logging.error(f"Error reading YAML file: {err}")
            raise err


def clear_folder(path: str):
    """Removes all files and subdirectories in the specified folder."""
    if not os.path.exists(path):
        print(f"Path '{path}' does not exist.")
        return

    for item in os.listdir(path):
        item_path = os.path.join(path, item)
        try:
            if os.path.isfile(item_path) or os.path.islink(item_path):
                os.remove(item_path)  # Delete file or symbolic link
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path)  # Delete directory
        except Exception as e:
            logging.error(f"Failed to delete {item_path}: {e}")

    logging.info(f"All files and folders in '{path}' have been cleared.")
