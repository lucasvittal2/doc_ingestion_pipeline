import asyncio
import datetime
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, Optional

import aiohttp
import apache_beam as beam
from llama_index.core.node_parser import SentenceWindowNodeParser, get_leaf_nodes
from llama_index.core.schema import Document
from llama_index.readers.file import PDFReader

from doc_ingestion_pipeline.beam.dofunctions.base_dofn import BaseDoFn
from doc_ingestion_pipeline.llm.extract_topics import OpenAITopicExtractor
from doc_ingestion_pipeline.utils.app_logging import LoggerHandler


class GenerateChunksDoFn(BaseDoFn):

    def __init__(self, logger_handler: LoggerHandler):
        super().__init__(logger_handler)

    def setup(self):
        super().setup()

    @BaseDoFn.gauge
    def process(self, element: Dict[str, str], *args, **kwargs):

        pdf_path = Path(element["pdf_path"])
        documents = PDFReader().load_data(pdf_path)

        node_parser = SentenceWindowNodeParser.from_defaults(
            window_size=5,
            window_metadata_key="window",
            original_text_metadata_key="original_text",
        )
        nodes = node_parser.get_nodes_from_documents(documents)
        chunks = []
        for node in nodes:

            metadata = node.metadata
            chunk = {
                "id": node.id_,
                "text": metadata["window"],
                "source_doc": metadata["file_name"],
                "page_number": int(metadata["page_label"]),
            }
            chunks.append(chunk)

        yield from chunks


class ExtractPageTopicDoFn(BaseDoFn):
    def __init__(self, loggger_hanlder: LoggerHandler, app_configs: dict):
        self.topic_extractor = OpenAITopicExtractor(loggger_hanlder, app_configs)
        super().__init__(loggger_hanlder)
        # self.topic_extractor = OpenAITopicExtractor(logger, app_configs)

    def setup(self):
        super().setup()

    @BaseDoFn.gauge
    def process(self, element: Dict[str, str], *args, **kwargs):
        chunk = element.copy()
        topics = self.topic_extractor.extract_topics(chunk["text"])
        chunk["topics"] = topics
        yield chunk
