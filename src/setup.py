import os
import re

import setuptools
from setuptools import find_packages

PROJECT_NAME = "doc_ingestion_pipeline"
AUTHOR_TEAM = "Lucas Vital"
AUTHOR_EMAIL = "lucasvittal@gmail.com"
DESCRIPTION = """
The **Bot Specialist** project aims to develop a chatbot capable of specializing in any domain of knowledge based on user-provided documents. With a simple PDF upload, the bot processes the content and enables users to ask any questions related to the document's knowledge domain.

A key feature of the bot is its ability to provide references for its responses, ensuring users can verify the accuracy of the answers and perform further checks if needed. This functionality makes the bot a reliable assistant for various information-seeking tasks, including studying, business research, and general information retrieval.

The ultimate goal is to create an application that serves as an intelligent assistant for diverse information-related activities, enhancing productivity and reliability in decision-making.
"""


def get_version():
    with open("./doc_ingestion_pipeline/__init__.py") as f:
        init_contents = f.read()
    version_match = re.search(
        r'^__version__\s*=\s*[\'"]([^\'"]+)[\'"]', init_contents, re.MULTILINE
    )
    if version_match:
        return version_match.group(1)
    raise RuntimeError("Version not found in __init__.py")


VERSION = get_version()
BEAM_VERSION = os.environ.get("BEAM_VERSION", "2.59.0")

dependencies = [
    f"apache-beam[gcp]=={BEAM_VERSION}",
    "aiohttp==3.11.9",
    "tiktoken==0.8.0",
    "openai==1.55.3",
    "scikit-learn==1.5.1",
    "google-cloud-secret-manager==2.20.0",
    "google-cloud-bigquery==3.26.0",
    "uvicorn==0.34.0",
    "fastapi==0.115.6",
]

setuptools.setup(
    name=PROJECT_NAME,
    version=VERSION,
    author=AUTHOR_TEAM,
    author_email=AUTHOR_EMAIL,
    description=DESCRIPTION,
    install_requires=dependencies,
    packages=find_packages(),
    include_package_data=True,
    zip_safe=False,
)
