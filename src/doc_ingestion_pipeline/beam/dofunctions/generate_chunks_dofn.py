import asyncio
import datetime
import json
from collections import defaultdict

import aiohttp
import apache_beam as beam

from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn


class GenerateChunksDoFn(BaseDoFn):

    def __init__(self):
        pass

    def setup(self):
        super().setup()

    def teardown(self):
        pass

    @BaseDoFn.gauge
    def process(self, element, *args, **kwargs):
        pass
